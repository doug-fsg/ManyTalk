require 'rails_helper'

RSpec.describe 'Inboxes sync_templates API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }

  before do
    allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService).to receive(:sync_templates).and_return(true)
  end

  it 'syncs templates for whatsapp cloud inbox' do
    post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/sync_templates",
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['message_templates']).to be_present
  end
end
