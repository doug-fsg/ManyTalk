class Enterprise::Billing::HandleStripeEventService
  def perform(event:)
    @event = event

    case event.type
    when 'customer.subscription.updated' then sync_subscription
    when 'customer.subscription.deleted' then mark_subscription_canceled
    else
      Rails.logger.debug { "Unhandled event type: #{event.type}" }
    end
  end

  private

  def sync_subscription
    return if account.blank?
    return unless subscription_matches_account?

    subscription_item_id = account.custom_attributes['stripe_subscription_item_id']
    product_id = Enterprise::Billing::SubscriptionAttributes.product_id(subscription, item_id: subscription_item_id)
    return if product_id.blank?

    product_name = manytalks_payload_product_name(subscription_item_id)
    plan_name = Enterprise::Billing::PlanNameResolver.resolve(
      product_id,
      fallback_name: account.custom_attributes['plan_name'],
      product_name: product_name,
      fetch_from_stripe: false
    )
    return if plan_name.blank?

    period_end = Enterprise::Billing::SubscriptionAttributes.current_period_end(subscription, item_id: subscription_item_id)
    status = Enterprise::Billing::SubscriptionAttributes.status(subscription)

    Enterprise::Billing::CustomAttributes.merge!(
      account,
      stripe_customer_id: customer_id,
      stripe_subscription_id: Enterprise::Billing::SubscriptionAttributes.subscription_id(subscription),
      stripe_price_id: Enterprise::Billing::SubscriptionAttributes.price_id(subscription, item_id: subscription_item_id),
      stripe_product_id: product_id,
      plan_name: plan_name,
      subscribed_quantity: Enterprise::Billing::SubscriptionAttributes.quantity(subscription, item_id: subscription_item_id),
      subscription_status: status,
      subscription_ends_on: period_end.present? ? Time.zone.at(period_end) : nil
    )
  end

  def mark_subscription_canceled
    return if account.blank?
    return unless subscription_matches_account?

    Enterprise::Billing::CustomAttributes.merge!(account, subscription_status: 'canceled')
  end

  def subscription_matches_account?
    stored_subscription_id = account.custom_attributes['stripe_subscription_id'].presence
    return true if stored_subscription_id.blank?

    stored_subscription_id == Enterprise::Billing::SubscriptionAttributes.subscription_id(subscription)
  end

  def subscription
    @subscription ||= @event.data.object
  end

  def customer_id
    @customer_id ||= Enterprise::Billing::SubscriptionAttributes.customer_id(subscription)
  end

  def manytalks_payload_product_name(subscription_item_id)
    return unless Enterprise::Billing::DeploymentEnv.manytalks?

    Enterprise::Billing::SubscriptionAttributes.product_name(subscription, item_id: subscription_item_id)
  end

  def account
    return @account if defined?(@account)

    @account = Account.find_by("custom_attributes->>'stripe_customer_id' = ?", customer_id) if customer_id.present?
  end
end
