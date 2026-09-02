require 'rails_helper'

describe Enterprise::Billing::CreateStripeCustomerService do
  subject(:create_stripe_customer_service) { described_class }

  let(:account) { create(:account) }
  let!(:admin1) { create(:user, account: account, role: :administrator) }
  let(:admin2) { create(:user, account: account, role: :administrator) }

  describe '#perform' do
    before do
      config = InstallationConfig.find_or_initialize_by(name: 'CHATWOOT_CLOUD_PLANS')
      config.value = [
        { 'name' => 'A Plan Name', 'product_id' => ['prod_hacker_random'], 'price_ids' => ['price_hacker_random'] }
      ]
      config.save!
    end

    context 'when auto provision is disabled (default)' do
      before do
        config = InstallationConfig.find_or_initialize_by(name: 'STRIPE_AUTO_PROVISION_CUSTOMERS')
        config.value = false
        config.save!
      end

      it 'does not call stripe methods' do
        account.update!(custom_attributes: { onboarding_step: 'keep-me' })
        allow(Stripe::Customer).to receive(:create)
        allow(Stripe::Subscription).to receive(:create)

        create_stripe_customer_service.new(account: account).perform

        expect(Stripe::Customer).not_to have_received(:create)
        expect(Stripe::Subscription).not_to have_received(:create)
        expect(account.reload.custom_attributes).to eq({ 'onboarding_step' => 'keep-me' })
      end
    end

    context 'when auto provision is enabled' do
      before do
        config = InstallationConfig.find_or_initialize_by(name: 'STRIPE_AUTO_PROVISION_CUSTOMERS')
        config.value = true
        config.save!
      end

      it 'does not call stripe customer create if customer id is present' do
        account.update!(custom_attributes: { stripe_customer_id: 'cus_random_number', onboarding_step: 'keep-me' })

        allow(Stripe::Customer).to receive(:create)
        allow(Stripe::Subscription).to receive(:create)
          .and_return(
            {
              plan: { id: 'price_random_number', product: 'prod_random_number' },
              quantity: 2
            }.with_indifferent_access
          )

        create_stripe_customer_service.new(account: account).perform

        expect(Stripe::Customer).not_to have_received(:create)
        expect(Stripe::Subscription)
          .to have_received(:create)
          .with({ customer: 'cus_random_number', items: [{ price: 'price_hacker_random', quantity: 2 }] })

        expect(account.reload.custom_attributes).to include(
          'stripe_customer_id' => 'cus_random_number',
          'stripe_price_id' => 'price_random_number',
          'stripe_product_id' => 'prod_random_number',
          'subscribed_quantity' => 2,
          'plan_name' => 'A Plan Name',
          'onboarding_step' => 'keep-me'
        )
      end

      it 'calls stripe methods to create a customer and updates the account' do
        customer = double
        allow(Stripe::Customer).to receive(:create).and_return(customer)
        allow(customer).to receive(:id).and_return('cus_random_number')
        allow(Stripe::Subscription)
          .to receive(:create)
          .and_return(
            {
              plan: { id: 'price_random_number', product: 'prod_random_number' },
              quantity: 2
            }.with_indifferent_access
          )

        create_stripe_customer_service.new(account: account).perform

        expect(Stripe::Customer).to have_received(:create).with({ name: account.name, email: admin1.email })
        expect(Stripe::Subscription)
          .to have_received(:create)
          .with({ customer: customer.id, items: [{ price: 'price_hacker_random', quantity: 2 }] })

        expect(account.reload.custom_attributes).to include(
          'stripe_customer_id' => customer.id,
          'stripe_price_id' => 'price_random_number',
          'stripe_product_id' => 'prod_random_number',
          'subscribed_quantity' => 2,
          'plan_name' => 'A Plan Name'
        )
      end
    end
  end
end
