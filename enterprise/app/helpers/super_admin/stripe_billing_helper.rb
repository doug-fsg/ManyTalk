module SuperAdmin::StripeBillingHelper
  LINKED_STATUSES = %w[active trialing].freeze
  WARNING_STATUSES = %w[past_due unpaid incomplete].freeze

  def stripe_billing_state(attrs)
    customer_id = attrs[:stripe_customer_id].presence
    subscription_status = attrs[:subscription_status].to_s.presence

    if customer_id.blank?
      { key: :not_linked, label: 'Not linked' }
    elsif subscription_status == 'canceled'
      { key: :canceled, label: 'Canceled' }
    elsif WARNING_STATUSES.include?(subscription_status)
      { key: :warning, label: subscription_status.humanize }
    elsif LINKED_STATUSES.include?(subscription_status)
      { key: :linked_active, label: subscription_status.humanize }
    elsif subscription_status.present?
      { key: :linked, label: subscription_status.humanize }
    else
      { key: :linked, label: 'Linked' }
    end
  end

  def stripe_status_badge_classes(state_key)
    {
      not_linked: 'bg-slate-100 text-slate-700',
      linked_active: 'bg-green-100 text-green-800',
      linked: 'bg-slate-100 text-slate-800',
      canceled: 'bg-red-100 text-red-800',
      warning: 'bg-amber-100 text-amber-900'
    }.fetch(state_key, 'bg-slate-100 text-slate-700')
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
end
