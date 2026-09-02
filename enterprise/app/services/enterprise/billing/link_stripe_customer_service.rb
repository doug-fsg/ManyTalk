class Enterprise::Billing::LinkStripeCustomerService
  class Error < StandardError; end

  Result = Struct.new(:account, :customer, keyword_init: true)

  USABLE_STATUSES = %w[active trialing].freeze
  CUSTOMER_ID_FORMAT = /\Acus_[A-Za-z0-9]+\z/

  pattr_initialize [:account!, :stripe_customer_id!]

  def perform
    customer_id = stripe_customer_id.to_s.strip
    validate_format!(customer_id)
    ensure_unique!(customer_id)

    customer = retrieve_customer(customer_id)
    subscription = pick_usable_subscription(customer_id)
    billing_attrs = attributes_from(customer, customer_id, subscription)

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

  def pick_usable_subscription(customer_id)
    subscriptions = Stripe::Subscription.list(customer: customer_id, status: 'all', limit: 100)
    usable = subscriptions.data.select { |sub| USABLE_STATUSES.include?(sub.status) }

    raise Error, 'Este customer não tem assinatura active ou trialing. Resolva no Stripe e tente de novo.' if usable.empty?
    raise Error, 'Este customer tem mais de uma assinatura ativa. Deixe só uma no Stripe e tente de novo.' if usable.size > 1

    usable.first
  rescue Stripe::StripeError => e
    raise Error, "Não foi possível listar assinaturas no Stripe: #{e.message}"
  end

  def attributes_from(customer, customer_id, subscription)
    product_id = product_id_for(subscription)
    plan = Enterprise::Billing::CloudPlans.plan_for_product(product_id)
    raise Error, 'O product desta assinatura não está em CHATWOOT_CLOUD_PLANS. Alinhe o catálogo e tente de novo.' if plan.blank?

    period_end = current_period_end_for(subscription)

    {
      stripe_customer_id: customer_id,
      stripe_customer_name: customer.name.presence,
      stripe_customer_email: customer.email.presence,
      stripe_price_id: price_id_for(subscription),
      stripe_product_id: product_id,
      plan_name: plan['name'],
      subscribed_quantity: quantity_for(subscription),
      subscription_status: subscription.status,
      subscription_ends_on: period_end.present? ? Time.zone.at(period_end) : nil
    }
  end

  def product_id_for(subscription)
    plan = subscription['plan']
    return plan['product'] if plan.present?

    price = first_item(subscription)&.price
    product = price&.product
    product.is_a?(String) ? product : product&.id
  end

  def price_id_for(subscription)
    plan = subscription['plan']
    return plan['id'] if plan.present?

    first_item(subscription)&.price&.id
  end

  def quantity_for(subscription)
    subscription['quantity'] || first_item(subscription)&.quantity
  end

  def current_period_end_for(subscription)
    subscription['current_period_end'] || first_item(subscription).try(:current_period_end)
  end

  def first_item(subscription)
    subscription.items&.data&.first
  end
end
