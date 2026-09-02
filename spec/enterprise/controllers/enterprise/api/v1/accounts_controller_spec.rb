require 'rails_helper'

RSpec.describe 'Enterprise Billing APIs', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'POST /enterprise/api/v1/accounts/{account.id}/subscription' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/enterprise/api/v1/accounts/#{account.id}/subscription", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'when it is an agent' do
        it 'returns unauthorized' do
          post "/enterprise/api/v1/accounts/#{account.id}/subscription",
               headers: agent.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when it is an admin' do
        it 'does not enqueue a job when auto provision is disabled' do
          config = InstallationConfig.find_or_initialize_by(name: 'STRIPE_AUTO_PROVISION_CUSTOMERS')
          config.value = false
          config.save!
          account.update!(custom_attributes: { onboarding_step: 'keep-me' })

          expect do
            post "/enterprise/api/v1/accounts/#{account.id}/subscription",
                 headers: admin.create_new_auth_token,
                 as: :json
          end.not_to have_enqueued_job(Enterprise::CreateStripeCustomerJob).with(account)
          expect(account.reload.custom_attributes).to eq({ 'onboarding_step' => 'keep-me' })
        end

        context 'when auto provision is enabled' do
          before do
            config = InstallationConfig.find_or_initialize_by(name: 'STRIPE_AUTO_PROVISION_CUSTOMERS')
            config.value = true
            config.save!
          end

          it 'enqueues a job and merges custom attributes' do
            account.update!(custom_attributes: { onboarding_step: 'keep-me' })

            expect do
              post "/enterprise/api/v1/accounts/#{account.id}/subscription",
                   headers: admin.create_new_auth_token,
                   as: :json
            end.to have_enqueued_job(Enterprise::CreateStripeCustomerJob).with(account)
            expect(account.reload.custom_attributes).to include(
              'is_creating_customer' => true,
              'onboarding_step' => 'keep-me'
            )
          end

          it 'does not enqueue a job if a job is already enqueued' do
            account.update!(custom_attributes: { is_creating_customer: true })

            expect do
              post "/enterprise/api/v1/accounts/#{account.id}/subscription",
                   headers: admin.create_new_auth_token,
                   as: :json
            end.not_to have_enqueued_job(Enterprise::CreateStripeCustomerJob).with(account)
          end

          it 'does not enqueues a job if customer id is present' do
            account.update!(custom_attributes: { 'stripe_customer_id': 'cus_random_string' })

            expect do
              post "/enterprise/api/v1/accounts/#{account.id}/subscription",
                   headers: admin.create_new_auth_token,
                   as: :json
            end.not_to have_enqueued_job(Enterprise::CreateStripeCustomerJob).with(account)
          end
        end
      end
    end
  end

  describe 'POST /enterprise/api/v1/accounts/{account.id}/checkout' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/enterprise/api/v1/accounts/#{account.id}/checkout", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'when it is an agent' do
        it 'returns unauthorized' do
          post "/enterprise/api/v1/accounts/#{account.id}/checkout",
               headers: agent.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when it is an admin and the stripe customer id is not present' do
        it 'returns error' do
          post "/enterprise/api/v1/accounts/#{account.id}/checkout",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Please subscribe to a plan before viewing the billing details')
        end
      end

      context 'when it is an admin and the stripe customer is present' do
        it 'calls create session' do
          account.update!(custom_attributes: { 'stripe_customer_id': 'cus_random_string' })

          create_session_service = double
          allow(Enterprise::Billing::CreateSessionService).to receive(:new).and_return(create_session_service)
          allow(create_session_service).to receive(:create_session).and_return(create_session_service)
          allow(create_session_service).to receive(:url).and_return('https://billing.stripe.com/random_string')

          post "/enterprise/api/v1/accounts/#{account.id}/checkout",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['redirect_url']).to eq('https://billing.stripe.com/random_string')
        end
      end
    end
  end

  describe 'GET /enterprise/api/v1/accounts/{account.id}/limits' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/enterprise/api/v1/accounts/#{account.id}/limits", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'when it is an agent' do
        it 'returns unauthorized' do
          get "/enterprise/api/v1/accounts/#{account.id}/limits",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when it is an admin' do
        before do
          create(:conversation, account: account)
          create(:channel_api, account: account)
          InstallationConfig.where(name: 'DEPLOYMENT_ENV').first_or_create(value: 'cloud')
          InstallationConfig.where(name: 'CHATWOOT_CLOUD_PLANS').first_or_create(value: [{ 'name': 'Hacker' }])
        end

        it 'returns the limits if the plan is default' do
          account.update!(custom_attributes: { plan_name: 'Hacker' })
          get "/enterprise/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expected_response = {
            'id' => account.id,
            'limits' => {
              'conversation' => {
                'allowed' => 500,
                'consumed' => 1
              },
              'non_web_inboxes' => {
                'allowed' => 0,
                'consumed' => 1
              }
            }
          }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_response)
        end

        it 'returns nil if the plan is not default' do
          account.update!(custom_attributes: { plan_name: 'Startups' })
          get "/enterprise/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expected_response = {
            'id' => account.id,
            'limits' => {
              'conversation' => {},
              'non_web_inboxes' => {}
            }
          }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_response)
        end

        it 'returns limits if a plan is not configured' do
          get "/enterprise/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expected_response = {
            'id' => account.id,
            'limits' => {
              'conversation' => {
                'allowed' => 500,
                'consumed' => 1
              },
              'non_web_inboxes' => {
                'allowed' => 0,
                'consumed' => 1
              }
            }
          }
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_response)
        end
      end

      context 'when DEPLOYMENT_ENV is manytalks' do
        before do
          InstallationConfig.where(name: 'DEPLOYMENT_ENV').first_or_create(value: 'manytalks').update!(value: 'manytalks')
          InstallationConfig.where(name: 'CHATWOOT_CLOUD_PLANS').first_or_create(value: [{ 'name': 'Hacker' }])
          create(:conversation, account: account) unless account.conversations.exists?
          create(:channel_api, account: account) unless account.inboxes.where(channel_type: Channel::Api.to_s).exists?
        end

        it 'returns empty limits when stripe_customer_id is not linked' do
          account.update!(custom_attributes: { plan_name: 'Hacker' })

          get "/enterprise/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(
            'id' => account.id,
            'limits' => {
              'conversation' => {},
              'non_web_inboxes' => {}
            }
          )
        end

        it 'returns plan limits when stripe_customer_id is linked and plan is default' do
          account.update!(custom_attributes: {
                            plan_name: 'Hacker',
                            stripe_customer_id: 'cus_linked123'
                          })

          get "/enterprise/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          body = JSON.parse(response.body)
          expect(response).to have_http_status(:ok)
          expect(body['limits']['conversation']['allowed']).to eq(500)
          expect(body['limits']['non_web_inboxes']['allowed']).to eq(0)
        end
      end
    end
  end
end
