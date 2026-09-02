require 'rails_helper'

describe Enterprise::Billing::LinkStripeCustomerService do
  subject(:service) { described_class.new(account: account, stripe_customer_id: customer_id) }

  let(:account) { create(:account, custom_attributes: { onboarding_step: 'keep-me' }) }
  let(:customer_id) { 'cus_abc123' }
  let(:customer) { double(id: customer_id, name: 'Acme', email: 'acme@example.com') }
  let(:subscription) { double(status: 'active') }

  before do
    config = InstallationConfig.find_or_initialize_by(name: 'CHATWOOT_CLOUD_PLANS')
    config.value = [
      { 'name' => 'Hacker', 'product_id' => ['prod_hacker'], 'price_ids' => ['price_1'] },
      { 'name' => 'Startups', 'product_id' => ['prod_startups'], 'price_ids' => ['price_2'] }
    ]
    config.save!
    allow(Stripe::Customer).to receive(:create)
    allow(Stripe::Subscription).to receive(:create)
  end

  def stub_usable_subscription(product: 'prod_startups')
    allow(subscription).to receive(:[]).with('plan').and_return({ 'id' => 'price_2', 'product' => product })
    allow(subscription).to receive(:[]).with('quantity').and_return(5)
    allow(subscription).to receive(:[]).with('current_period_end').and_return(1_686_567_520)
    allow(Stripe::Customer).to receive(:retrieve).with(customer_id).and_return(customer)
    allow(Stripe::Subscription).to receive(:list)
      .with(customer: customer_id, status: 'all', limit: 100)
      .and_return(double(data: [subscription]))
  end

  describe '#perform' do
    it 'links the customer and preserves existing custom attributes' do
      stub_usable_subscription

      result = service.perform

      expect(Stripe::Customer).not_to have_received(:create)
      expect(Stripe::Subscription).not_to have_received(:create)
      expect(result.customer).to eq(customer)
      expect(account.reload.custom_attributes).to include(
        'onboarding_step' => 'keep-me',
        'stripe_customer_id' => customer_id,
        'stripe_customer_name' => 'Acme',
        'stripe_customer_email' => 'acme@example.com',
        'stripe_price_id' => 'price_2',
        'stripe_product_id' => 'prod_startups',
        'plan_name' => 'Startups',
        'subscribed_quantity' => 5,
        'subscription_status' => 'active'
      )
    end

    it 'does not change features on link' do
      stub_usable_subscription
      account.enable_features('channel_email')
      account.save!

      service.perform

      expect(account.reload).to be_feature_enabled('channel_email')
    end

    it 'rejects an invalid customer id format' do
      expect do
        described_class.new(account: account, stripe_customer_id: 'not-a-customer').perform
      end.to raise_error(described_class::Error, /cus_/)
      expect(Stripe::Customer).not_to have_received(:create)
    end

    it 'rejects a customer id already used by another account' do
      create(:account, custom_attributes: { stripe_customer_id: customer_id })
      expect { service.perform }.to raise_error(described_class::Error, /já está vinculado/)
    end

    it 'rejects a missing stripe customer' do
      allow(Stripe::Customer).to receive(:retrieve)
        .and_raise(Stripe::InvalidRequestError.new('No such customer', 'id'))

      expect { service.perform }.to raise_error(described_class::Error, /não encontrado/)
    end

    it 'rejects when there is no usable subscription' do
      canceled = double(status: 'canceled')
      allow(canceled).to receive(:[]).with('plan').and_return({ 'id' => 'price_2', 'product' => 'prod_startups' })
      allow(Stripe::Customer).to receive(:retrieve).with(customer_id).and_return(customer)
      allow(Stripe::Subscription).to receive(:list)
        .and_return(double(data: [canceled]))

      expect { service.perform }.to raise_error(described_class::Error, /não tem assinatura/)
    end

    it 'rejects when there are multiple active subscriptions' do
      first = double(status: 'active')
      second = double(status: 'trialing')
      allow(Stripe::Customer).to receive(:retrieve).with(customer_id).and_return(customer)
      allow(Stripe::Subscription).to receive(:list)
        .and_return(double(data: [first, second]))

      expect { service.perform }.to raise_error(described_class::Error, /mais de uma assinatura/)
    end

    it 'rejects when the product is not in CHATWOOT_CLOUD_PLANS' do
      stub_usable_subscription(product: 'prod_unknown')

      expect { service.perform }.to raise_error(described_class::Error, /CHATWOOT_CLOUD_PLANS/)
      expect(account.reload.custom_attributes).to eq({ 'onboarding_step' => 'keep-me' })
    end
  end
end
