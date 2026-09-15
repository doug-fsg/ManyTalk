module SuperAdmin::StripeBillingHelper
  def stripe_link_choices
    return if session[:stripe_link_choices].blank?

    session[:stripe_link_choices].with_indifferent_access
  end

  LINKED_STATUSES = %w[active trialing].freeze
  WARNING_STATUSES = %w[past_due incomplete].freeze
  LOCKED_STATUSES = %w[unpaid canceled incomplete_expired].freeze

  def stripe_billing_state(attrs)
    customer_id = attrs[:stripe_customer_id].presence
    subscription_status = attrs[:subscription_status].to_s.presence

    if customer_id.blank?
      { key: :not_linked, label: 'Não vinculado' }
    elsif LOCKED_STATUSES.include?(subscription_status)
      { key: :billing_locked, label: translate_subscription_status(subscription_status) }
    elsif WARNING_STATUSES.include?(subscription_status)
      { key: :warning, label: translate_subscription_status(subscription_status) }
    elsif LINKED_STATUSES.include?(subscription_status)
      { key: :linked_active, label: translate_subscription_status(subscription_status) }
    elsif subscription_status.present?
      { key: :linked, label: translate_subscription_status(subscription_status) }
    else
      { key: :linked, label: 'Vinculado' }
    end
  end

  def stripe_status_badge_classes(state_key)
    {
      not_linked: 'stripe-billing__badge stripe-billing__badge--neutral',
      linked_active: 'stripe-billing__badge stripe-billing__badge--active',
      linked: 'stripe-billing__badge stripe-billing__badge--neutral',
      billing_locked: 'stripe-billing__badge stripe-billing__badge--danger',
      warning: 'stripe-billing__badge stripe-billing__badge--warning'
    }.fetch(state_key, 'stripe-billing__badge stripe-billing__badge--neutral')
  end

  def stripe_mode_label
    stripe_test_mode? ? 'Modo teste' : 'Modo live'
  end

  def stripe_technical_fields(attrs)
    attrs = attrs.with_indifferent_access
    [
      ['Customer ID', attrs[:stripe_customer_id]],
      ['Subscription ID', attrs[:stripe_subscription_id]],
      ['Subscription item ID', attrs[:stripe_subscription_item_id]],
      ['Price ID', attrs[:stripe_price_id]],
      ['Product ID', attrs[:stripe_product_id]]
    ]
  end

  def stripe_dashboard_customer_url(customer_id)
    return if customer_id.blank?

    prefix = stripe_test_mode? ? 'https://dashboard.stripe.com/test/customers/' : 'https://dashboard.stripe.com/customers/'
    "#{prefix}#{customer_id}"
  end

  def stripe_test_mode?
    key = ENV.fetch('STRIPE_SECRET_KEY', '')
    key.blank? || key.start_with?('sk_test_')
  end

  def format_stripe_timestamp(value)
    return '—' if value.blank?

    Time.zone.parse(value.to_s).strftime('%d/%m/%Y %H:%M')
  rescue ArgumentError, TypeError
    value.to_s
  end

  def stripe_auto_provision_enabled?
    Enterprise::Billing::AutoProvision.enabled?
  end

  private

  def translate_subscription_status(status)
    {
      'active' => 'Ativo',
      'trialing' => 'Em trial',
      'past_due' => 'Pagamento pendente',
      'unpaid' => 'Não pago',
      'canceled' => 'Cancelado',
      'incomplete' => 'Incompleto',
      'incomplete_expired' => 'Expirado'
    }.fetch(status.to_s, status.to_s.humanize)
  end
end
