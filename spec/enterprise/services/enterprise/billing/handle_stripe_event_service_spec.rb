require 'rails_helper'

describe Enterprise::Billing::HandleStripeEventService do
  subject(:stripe_event_service) { described_class }

  let(:event) { double }
  let(:data) { double }
  let(:subscription) { double }
  let!(:account) { create(:account, custom_attributes: { stripe_customer_id: 'cus_123', onboarding_step: 'keep-me' }) }

  before do
    allow(event).to receive(:data).and_return(data)
    allow(data).to receive(:object).and_return(subscription)
    allow(subscription).to receive(:[]).with('plan')
                                       .and_return({
                                                     'id' => 'test', 'product' => 'plan_id', 'name' => 'plan_name'
                                                   })
    allow(subscription).to receive(:[]).with('quantity').and_return('10')
    allow(subscription).to receive(:[]).with('status').and_return('active')
    allow(subscription).to receive(:[]).with('current_period_end').and_return(1_686_567_520)
    allow(subscription).to receive(:customer).and_return('cus_123')
    config = InstallationConfig.find_or_initialize_by(name: 'CHATWOOT_CLOUD_PLANS')
    config.value = [
      {
        'name' => 'Hacker',
        'product_id' => ['plan_id'],
        'price_ids' => ['price_1']
      },
      {
        'name' => 'Startups',
        'product_id' => ['plan_id_2'],
        'price_ids' => ['price_2']
      }
    ]
    config.save!
  end

  describe '#perform' do
    it 'handle customer.subscription.updated' do
      allow(event).to receive(:type).and_return('customer.subscription.updated')
      allow(subscription).to receive(:customer).and_return('cus_123')
      stripe_event_service.new.perform(event: event)
      expect(account.reload.custom_attributes).to include(
        'stripe_customer_id' => 'cus_123',
        'stripe_price_id' => 'test',
        'stripe_product_id' => 'plan_id',
        'plan_name' => 'Hacker',
        'subscribed_quantity' => '10',
        'subscription_ends_on' => Time.zone.at(1_686_567_520).as_json,
        'subscription_status' => 'active',
        'onboarding_step' => 'keep-me'
      )
    end

    it 'does not change features on customer.subscription.updated' do
      allow(event).to receive(:type).and_return('customer.subscription.updated')
      allow(subscription).to receive(:customer).and_return('cus_123')
      account.enable_features('channel_email', 'help_center')
      account.save!

      stripe_event_service.new.perform(event: event)

      expect(account.reload.custom_attributes).to include(
        'plan_name' => 'Hacker',
        'onboarding_step' => 'keep-me'
      )
      expect(account).to be_feature_enabled('channel_email')
      expect(account).to be_feature_enabled('help_center')
    end

    it 'suspends the account on customer.subscription.deleted without changing features' do
      allow(event).to receive(:type).and_return('customer.subscription.deleted')
      allow(Enterprise::Billing::CreateStripeCustomerService).to receive(:new)
      allow(Stripe::Customer).to receive(:create)
      allow(Stripe::Subscription).to receive(:create)
      account.update!(custom_attributes: account.custom_attributes.merge('plan_name' => 'Startups'))
      account.enable_features('channel_email', 'help_center')
      account.save!

      stripe_event_service.new.perform(event: event)

      expect(Enterprise::Billing::CreateStripeCustomerService).not_to have_received(:new)
      expect(Stripe::Customer).not_to have_received(:create)
      expect(Stripe::Subscription).not_to have_received(:create)
      expect(account.reload).to be_suspended
      expect(account.custom_attributes).to include(
        'stripe_customer_id' => 'cus_123',
        'subscription_status' => 'canceled',
        'plan_name' => 'Startups',
        'onboarding_step' => 'keep-me'
      )
      expect(account).to be_feature_enabled('channel_email')
      expect(account).to be_feature_enabled('help_center')
    end

    it 'reactivates the account when subscription becomes active again' do
      account.update!(status: :suspended, custom_attributes: account.custom_attributes.merge('subscription_status' => 'canceled'))
      allow(event).to receive(:type).and_return('customer.subscription.updated')
      allow(subscription).to receive(:customer).and_return('cus_123')

      stripe_event_service.new.perform(event: event)

      expect(account.reload).to be_active
      expect(account.custom_attributes['subscription_status']).to eq('active')
    end
  end

  describe '#perform for Startups plan' do
    before do
      allow(event).to receive(:data).and_return(data)
      allow(data).to receive(:object).and_return(subscription)
      allow(subscription).to receive(:[]).with('plan')
                                         .and_return({
                                                       'id' => 'test', 'product' => 'plan_id_2', 'name' => 'plan_name'
                                                     })
      allow(subscription).to receive(:[]).with('quantity').and_return('10')
      allow(subscription).to receive(:customer).and_return('cus_123')
    end

    it 'does not change features on customer.subscription.updated' do
      allow(event).to receive(:type).and_return('customer.subscription.updated')
      allow(subscription).to receive(:customer).and_return('cus_123')

      stripe_event_service.new.perform(event: event)
      expect(account.reload.custom_attributes).to include(
        'stripe_customer_id' => 'cus_123',
        'stripe_price_id' => 'test',
        'stripe_product_id' => 'plan_id_2',
        'plan_name' => 'Startups',
        'subscribed_quantity' => '10',
        'subscription_ends_on' => Time.zone.at(1_686_567_520).as_json,
        'subscription_status' => 'active',
        'onboarding_step' => 'keep-me'
      )
      expect(account).not_to be_feature_enabled('channel_email')
      expect(account).not_to be_feature_enabled('help_center')
    end
  end
end
