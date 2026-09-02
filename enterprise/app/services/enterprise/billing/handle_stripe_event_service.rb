class Enterprise::Billing::HandleStripeEventService
  ACTIVE_STATUSES = %w[active trialing].freeze

  def perform(event:)
    @event = event

    case event.type
    when 'customer.subscription.updated' then sync_subscription
    when 'customer.subscription.deleted' then suspend_account
    else
      Rails.logger.debug { "Unhandled event type: #{event.type}" }
    end
  end

  private

  def sync_subscription
    return if account.blank? || subscription['plan'].blank?

    plan = Enterprise::Billing::CloudPlans.plan_for_product(subscription['plan']['product'])
    return if plan.blank?

    Enterprise::Billing::CustomAttributes.merge!(
      account,
      stripe_customer_id: subscription.customer,
      stripe_price_id: subscription['plan']['id'],
      stripe_product_id: subscription['plan']['product'],
      plan_name: plan['name'],
      subscribed_quantity: subscription['quantity'],
      subscription_status: subscription['status'],
      subscription_ends_on: Time.zone.at(subscription['current_period_end'])
    )

    account.active! if ACTIVE_STATUSES.include?(subscription['status'])
  end

  def suspend_account
    return if account.blank?

    Enterprise::Billing::CustomAttributes.merge!(account, subscription_status: 'canceled')
    account.suspended!
  end

  def subscription
    @subscription ||= @event.data.object
  end

  def account
    @account ||= Account.find_by("custom_attributes->>'stripe_customer_id' = ?", subscription.customer)
  end
end
