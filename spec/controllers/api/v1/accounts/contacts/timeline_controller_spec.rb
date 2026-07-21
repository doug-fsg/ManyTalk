# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Contact Timeline API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, :with_email, account: account) }

  describe 'GET /api/v1/accounts/:account_id/contacts/:contact_id/timeline' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/timeline"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns timeline events' do
        account_form = create(:account_form, :published, account: account, name: 'Form A')
        FormSubmission.create!(
          account: account,
          account_form: account_form,
          contact: contact,
          payload: { email: contact.email }
        )

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/timeline",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['meta']['count']).to be >= 2
        types = body['payload'].pluck('type')
        expect(types).to include('contact_created', 'form_submission')
      end
    end
  end
end
