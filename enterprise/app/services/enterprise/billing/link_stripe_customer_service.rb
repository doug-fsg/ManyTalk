class Enterprise::Billing::LinkStripeCustomerService
  class Error < StandardError; end

  class AmbiguousSubscriptionError < Error
    attr_reader :choice_type, :choices

    def initialize(message, choice_type:, choices:)
      super(message)
      @choice_type = choice_type
      @choices = choices
    end
  end

  Result = Struct.new(:account, :customer, keyword_init: true)

  USABLE_STATUSES = %w[active trialing].freeze
  CUSTOMER_ID_FORMAT = /\Acus_[A-Za-z0-9]+\z/

  pattr_initialize [:account!, :stripe_customer_id!, :stripe_subscription_id, :stripe_subscription_item_id]

  def perform
    customer_id = stripe_customer_id.to_s.strip
    validate_format!(customer_id)
    ensure_unique!(customer_id)

    customer = retrieve_customer(customer_id)
    subscription = pick_subscription(customer_id)
    subscription_item_id = pick_subscription_item_id(subscription)
    billing_attrs = attributes_from(customer, customer_id, subscription, subscription_item_id)

    Enterprise::Billing::CustomAttributes.merge!(account, billing_attrs)
    account.reload

    Result.new(account: account, customer: customer)
  end

  private

  def validate_format!(customer_id)
    return if customer_id.match?(CUSTOMER_ID_FORMAT)

    raise Error, 'Informe um Customer ID válido do Stripe (começa com cus_).'
  end

  def ensure_unique!(customer_id)
    taken = Account.where.not(id: account.id)
                   .where("custom_attributes->>'stripe_customer_id' = ?", customer_id)
                   .pick(:id)
    return if taken.blank?

    raise Error, "Este Customer ID já está vinculado à account ##{taken}."
  end

  def retrieve_customer(customer_id)
    Stripe::Customer.retrieve(customer_id)
  rescue Stripe::InvalidRequestError
    raise Error, 'Customer não encontrado no Stripe.'
  rescue Stripe::StripeError => e
    raise Error, "Não foi possível consultar o Stripe: #{e.message}"
  end

  def pick_subscription(customer_id)
    subscriptions = list_usable_subscriptions(customer_id)
    return subscriptions.first if subscriptions.size == 1

    if stripe_subscription_id.present?
      selected = subscriptions.find do |subscription|
        Enterprise::Billing::SubscriptionAttributes.subscription_id(subscription) == stripe_subscription_id
      end
      raise Error, 'A assinatura selecionada não está active/trialing neste customer.' if selected.blank?

      return selected
    end

    raise AmbiguousSubscriptionError.new(
      'Este customer tem mais de uma assinatura active/trialing. Selecione qual assinatura usar.',
      choice_type: 'subscription',
      choices: Enterprise::Billing::StripeLinkChoiceBuilder.subscription_choices(subscriptions)
    )
  end

  def pick_subscription_item_id(subscription)
    items = Enterprise::Billing::SubscriptionAttributes.items(subscription)
    return Enterprise::Billing::SubscriptionAttributes.subscription_item_id(subscription) if items.size <= 1

    if stripe_subscription_item_id.present?
      selected = items.find { |item| item.id == stripe_subscription_item_id }
      raise Error, 'O item de assinatura selecionado não pertence a esta subscription.' if selected.blank?

      return stripe_subscription_item_id
    end

    raise AmbiguousSubscriptionError.new(
      'Esta assinatura tem mais de um item. Selecione qual item representa o plano desta account.',
      choice_type: 'subscription_item',
      choices: Enterprise::Billing::StripeLinkChoiceBuilder.subscription_item_choices(subscription)
    )
  end

  def list_usable_subscriptions(customer_id)
    subscriptions = Stripe::Subscription.list(customer: customer_id, status: 'all', limit: 100)
    usable = subscriptions.data.select { |sub| USABLE_STATUSES.include?(Enterprise::Billing::SubscriptionAttributes.status(sub)) }

    raise Error, 'Este customer não tem assinatura active ou trialing. Resolva no Stripe e tente de novo.' if usable.empty?

    usable
  rescue Stripe::StripeError => e
    raise Error, "Não foi possível listar assinaturas no Stripe: #{e.message}"
  end

  def attributes_from(customer, customer_id, subscription, subscription_item_id)
    product_id = Enterprise::Billing::SubscriptionAttributes.product_id(subscription, item_id: subscription_item_id)
    raise Error, missing_product_error_message if product_id.blank?

    product_name = Enterprise::Billing::SubscriptionAttributes.product_name(subscription, item_id: subscription_item_id)
    plan_name = Enterprise::Billing::PlanNameResolver.resolve(
      product_id,
      product_name: product_name,
      fetch_from_stripe: product_name.blank?
    )
    raise Error, missing_product_error_message if plan_name.blank?

    period_end = Enterprise::Billing::SubscriptionAttributes.current_period_end(subscription, item_id: subscription_item_id)

    {
      stripe_customer_id: customer_id,
      stripe_customer_name: customer.name.presence,
      stripe_customer_email: customer.email.presence,
      stripe_subscription_id: Enterprise::Billing::SubscriptionAttributes.subscription_id(subscription),
      stripe_subscription_item_id: subscription_item_id,
      stripe_price_id: Enterprise::Billing::SubscriptionAttributes.price_id(subscription, item_id: subscription_item_id),
      stripe_product_id: product_id,
      plan_name: plan_name,
      subscribed_quantity: Enterprise::Billing::SubscriptionAttributes.quantity(subscription, item_id: subscription_item_id),
      subscription_status: Enterprise::Billing::SubscriptionAttributes.status(subscription),
      subscription_ends_on: period_end.present? ? Time.zone.at(period_end) : nil
    }
  end

  def missing_product_error_message
    if Enterprise::Billing::DeploymentEnv.manytalks?
      'Não foi possível identificar o produto desta assinatura. Verifique os items no Stripe e tente de novo.'
    else
      'O product desta assinatura não está em CHATWOOT_CLOUD_PLANS. Alinhe o catálogo e tente de novo.'
    end
  end
end
