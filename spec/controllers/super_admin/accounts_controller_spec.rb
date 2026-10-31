require 'rails_helper'

RSpec.describe 'Super Admin accounts API', type: :request do
  include ActiveJob::TestHelper

  let!(:super_admin) { create(:super_admin) }
  let!(:account) { create(:account) }

  describe 'GET /super_admin/accounts' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get '/super_admin/accounts'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows the list of accounts' do
        sign_in(super_admin, scope: :super_admin)
        get '/super_admin/accounts'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New account')
        expect(response.body).to include(account.name)
      end
    end
  end

  describe 'POST /super_admin/accounts/{account_id}/reset_cache' do
    before do
      create(:label, account: account)
      create(:inbox, account: account)
      create(:team, account: account)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/super_admin/accounts/#{account.id}/reset_cache"
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows the list of accounts' do
        expect(account.cache_keys.keys).to contain_exactly(:inbox, :label, :team)
        sign_in(super_admin, scope: :super_admin)

        now_timestamp = Time.now.utc.to_i
        post "/super_admin/accounts/#{account.id}/reset_cache"
        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to eq('Cache keys cleared')

        range = now_timestamp..(now_timestamp + 10)
        expect(account.reload.cache_keys.values.all? { |v| range.cover?(v.to_i) }).to be(true)
      end
    end
  end

  describe 'POST /super_admin/accounts/{account_id}/link_stripe' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/super_admin/accounts/#{account.id}/link_stripe", params: { stripe_customer_id: 'cus_abc123' }
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'links a stripe customer' do
        sign_in(super_admin, scope: :super_admin)
        result = instance_double(Enterprise::Billing::LinkStripeCustomerService::Result,
                                 customer: double(id: 'cus_abc123', name: 'Acme', email: 'acme@example.com'))
        allow(Enterprise::Billing::LinkStripeCustomerService).to receive(:new)
          .and_return(instance_double(Enterprise::Billing::LinkStripeCustomerService, perform: result))

        post "/super_admin/accounts/#{account.id}/link_stripe", params: { stripe_customer_id: 'cus_abc123' }

        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to include('cus_abc123')
        expect(flash[:notice]).to include('Acme')
      end

      it 'shows an error when linking fails' do
        sign_in(super_admin, scope: :super_admin)
        service = instance_double(Enterprise::Billing::LinkStripeCustomerService)
        allow(Enterprise::Billing::LinkStripeCustomerService).to receive(:new).and_return(service)
        allow(service).to receive(:perform).and_raise(Enterprise::Billing::LinkStripeCustomerService::Error, 'Customer não encontrado no Stripe.')

        post "/super_admin/accounts/#{account.id}/link_stripe", params: { stripe_customer_id: 'cus_missing' }

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to eq('Customer não encontrado no Stripe.')
      end
    end
  end

  describe 'PATCH /super_admin/accounts/{account_id}' do
    let(:account) { create(:account, ai_credit_limit: 100, ai_credits_used: 100) }
    let(:administrator) { create(:user, account: account, role: :administrator) }

    def patch_account_quota(attrs)
      sign_in(super_admin, scope: :super_admin)
      patch "/super_admin/accounts/#{account.id}", params: {
        account: {
          name: account.name,
          locale: account.locale,
          status: account.status
        }.merge(attrs)
      }
    end

    def get_ai_usage
      administrator.create_new_auth_token.except('Authorization').then do |headers|
        get "/api/v1/accounts/#{account.id}/ai_usage", headers: headers, as: :json
      end
    end

    context 'when Super Admin restores credits' do
      it 'unpauses configs paused for no_credits and GET paused agrees' do
        config = create(:ai_attendant_config, account: account, active: false, pause_reason: 'no_credits')
        admin_paused = create(:ai_attendant_config, account: account, active: false, pause_reason: 'admin')

        patch_account_quota(ai_credits_used: 0)

        expect(response).to have_http_status(:redirect)
        expect(account.reload.ai_credits_used).to eq(0)
        expect(config.reload).to have_attributes(active: true, pause_reason: nil)
        expect(admin_paused.reload).to have_attributes(active: false, pause_reason: 'admin')

        get_ai_usage

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['paused']).to be(false)
        expect(response.parsed_body['used']).to eq(0)
      end
    end

    context 'when Super Admin lowers the limit below used' do
      it 'pauses active configs for no_credits and GET paused agrees' do
        account.update!(ai_credits_used: 50, ai_credit_limit: 100)
        config = create(:ai_attendant_config, account: account, active: true)
        admin_paused = create(:ai_attendant_config, account: account, active: false, pause_reason: 'admin')

        patch_account_quota(ai_credit_limit: 40)

        expect(response).to have_http_status(:redirect)
        expect(account.reload.ai_credit_limit).to eq(40)
        expect(config.reload).to have_attributes(active: false, pause_reason: 'no_credits')
        expect(admin_paused.reload).to have_attributes(active: false, pause_reason: 'admin')

        get_ai_usage

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['paused']).to be(true)
      end
    end
  end

  describe 'DELETE /super_admin/accounts/{account_id}' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/super_admin/accounts/#{account.id}"
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'Deletes the account' do
        total_accounts = Account.count
        sign_in(super_admin, scope: :super_admin)

        perform_enqueued_jobs(only: DeleteObjectJob) do
          delete "/super_admin/accounts/#{account.id}"
        end

        expect(Account.count).to eq(total_accounts - 1)
      end
    end
  end
end
