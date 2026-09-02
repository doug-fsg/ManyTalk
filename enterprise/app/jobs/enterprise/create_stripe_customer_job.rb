class Enterprise::CreateStripeCustomerJob < ApplicationJob
  queue_as :default

  def perform(account)
    return unless Enterprise::Billing::AutoProvision.enabled?

    Enterprise::Billing::CreateStripeCustomerService.new(account: account).perform
  end
end
