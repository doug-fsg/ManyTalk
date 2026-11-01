# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ai Attendant Configs API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  # DeviseTokenAuth adds Authorization: Bearer <batch>, which AccessTokenAuthHelper
  # treats as an API access token and rejects. Dashboard auth uses access-token/uid/client.
  def auth_headers_for(user)
    user.create_new_auth_token.except('Authorization')
  end

  def json_body
    response.parsed_body
  end

  def secret_keys_in(payload)
    payload = payload.is_a?(Array) ? payload : [payload]
    payload.flat_map(&:keys).grep(/model|provider|api_key|openai/i)
  end

  describe 'GET /api/v1/accounts/{account.id}/ai_attendant_configs' do
    let!(:config) do
      create(:ai_attendant_config, account: account, inbox_id: inbox.id, digital_agent_name: 'Lia')
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_attendant_configs"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_attendant_configs",
            headers: auth_headers_for(agent),
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      it 'returns configs for the account without LLM secrets' do
        get "/api/v1/accounts/#{account.id}/ai_attendant_configs",
            headers: auth_headers_for(administrator),
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_body.length).to eq(1)
        expect(json_body.first['id']).to eq(config.id)
        expect(json_body.first['digital_agent_name']).to eq('Lia')
        expect(json_body.first['inbox_id']).to eq(inbox.id)
        expect(secret_keys_in(json_body)).to be_empty
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/ai_attendant_configs/:id' do
    let!(:config) { create(:ai_attendant_config, account: account, inbox_id: inbox.id) }

    context 'when it is an authenticated administrator' do
      it 'shows the config by id' do
        get "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}",
            headers: auth_headers_for(administrator),
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_body['id']).to eq(config.id)
        expect(secret_keys_in(json_body)).to be_empty
      end

      it 'shows the config by inbox_id query' do
        get "/api/v1/accounts/#{account.id}/ai_attendant_configs/0",
            params: { inbox_id: inbox.id },
            headers: auth_headers_for(administrator),
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_body['id']).to eq(config.id)
        expect(json_body['inbox_id']).to eq(inbox.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_attendant_configs' do
    let(:params) do
      {
        inbox_id: inbox.id,
        digital_agent_name: 'Lia',
        agent_role: 'Atendente',
        schedule_mode: 'always',
        debounce_seconds: 5
      }
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs", params: params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs",
             params: params,
             headers: auth_headers_for(agent),
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      it 'creates a config and assigns the digital sender user' do
        expect do
          post "/api/v1/accounts/#{account.id}/ai_attendant_configs",
               params: params,
               headers: auth_headers_for(administrator),
               as: :json
        end.to change(AiAttendantConfig, :count).by(1)

        expect(response).to have_http_status(:success)
        created = account.ai_attendant_configs.last
        expect(created.inbox_ids).to eq([inbox.id])
        expect(created.digital_agent_name).to eq('Lia')
        expect(created.sender_agent_bot).to be_present
        expect(created.sender_agent_bot.bot_config['kind']).to eq('ai_attendant')
        expect(created.sender_agent_bot.account_id).to eq(account.id)
        expect(account.users.where(id: created.sender_agent_bot_id)).to be_empty
        expect(created.avatar_id).to eq('avatar_1')
        expect(json_body).not_to have_key('sender_user_id')
        expect(secret_keys_in(json_body)).to be_empty
      end

      it 'does not take account_id from the client payload' do
        other_account = create(:account)
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs",
             params: params.merge(account_id: other_account.id),
             headers: auth_headers_for(administrator),
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.ai_attendant_configs.last.account_id).to eq(account.id)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/ai_attendant_configs/:id' do
    let!(:config) do
      create(:ai_attendant_config, account: account, inbox_id: inbox.id, digital_agent_name: 'Lia')
    end

    context 'when it is an authenticated agent' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}",
              params: { digital_agent_name: 'Novo' },
              headers: auth_headers_for(agent),
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      it 'updates the config' do
        patch "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}",
              params: { digital_agent_name: 'Novo', active: true },
              headers: auth_headers_for(administrator),
              as: :json

        expect(response).to have_http_status(:success)
        expect(config.reload.digital_agent_name).to eq('Novo')
        expect(config.active).to be(true)
        expect(json_body['digital_agent_name']).to eq('Novo')
      end

      it 'attaches uploaded reference files from blob ids' do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: File.open(Rails.root.join('spec/assets/avatar.png')),
          filename: 'IMG_5612.jpg',
          content_type: 'image/jpeg'
        )

        patch "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}",
              params: {
                digital_agent_name: 'Lia',
                reference_file_blob_ids: [blob.id],
                remove_reference_file_ids: []
              },
              headers: auth_headers_for(administrator),
              as: :json

        expect(response).to have_http_status(:success)
        config.reload
        expect(config.reference_files).to be_attached
        expect(config.reference_files.first.filename.to_s).to eq('IMG_5612.jpg')
        expect(json_body['reference_files'].first['filename']).to eq('IMG_5612.jpg')
        expect(json_body['reference_files'].first['token']).to eq('{{anexo:img_5612}}')
      end

      it 'renames a reference file from the short variable name' do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: File.open(Rails.root.join('spec/assets/avatar.png')),
          filename: '5895c30be7bce75cc5318a08.jpeg',
          content_type: 'image/jpeg'
        )

        patch "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}",
              params: {
                digital_agent_name: 'Lia',
                reference_file_blob_ids: [blob.id],
                reference_file_names: { blob.id.to_s => 'catalogo' }
              },
              headers: auth_headers_for(administrator),
              as: :json

        expect(response).to have_http_status(:success)
        config.reload
        expect(config.reference_files.first.filename.to_s).to eq('catalogo.jpeg')
        expect(json_body['reference_files'].first['token']).to eq('{{anexo:catalogo}}')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/ai_attendant_configs/:id' do
    let!(:config) { create(:ai_attendant_config, account: account, inbox_id: inbox.id) }

    context 'when it is an authenticated administrator' do
      it 'destroys the config' do
        expect do
          delete "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}",
                 headers: auth_headers_for(administrator),
                 as: :json
        end.to change(AiAttendantConfig, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_attendant_configs/:id/test' do
    let!(:config) { create(:ai_attendant_config, account: account, inbox_id: inbox.id) }

    context 'when it is an authenticated agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}/test",
             params: { message: 'oi' },
             headers: auth_headers_for(agent),
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      context 'when ChatService is stubbed' do
        let(:chat_service) do
          instance_double(AiAttendant::ChatService, perform: { text: 'Olá sandbox', handoff: false })
        end

        before do
          allow(AiAttendant::ChatService).to receive(:new).and_return(chat_service)
        end

        it 'returns reply and handoff without posting a public outgoing message' do
          expect do
            post "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}/test",
                 params: { message: 'oi' },
                 headers: auth_headers_for(administrator),
                 as: :json
          end.not_to change { Message.where(private: false, message_type: :outgoing).count }

          expect(response).to have_http_status(:success)
          expect(json_body['reply']).to eq('Olá sandbox')
          expect(json_body['handoff']).to be(false)
          expect(json_body['messages']).to eq(
            [{ 'type' => 'text', 'content' => 'Olá sandbox' }]
          )
          expect(AiAttendant::ChatService).to have_received(:new).with(
            hash_including(sandbox: true, history: [])
          )
          expect(chat_service).to have_received(:perform)
        end

        it 'resolves file variables into sandbox attachment messages' do
          config.reference_files.attach(
            io: File.open(Rails.root.join('spec/assets/avatar.png')),
            filename: 'catalogo.png',
            content_type: 'image/png'
          )
          allow(chat_service).to receive(:perform).and_return(
            { text: '{{anexo:catalogo}}', handoff: false }
          )

          post "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}/test",
               params: { message: 'manda o catalogo' },
               headers: auth_headers_for(administrator),
               as: :json

          expect(response).to have_http_status(:success)
          expect(json_body['messages']).to contain_exactly(
            hash_including(
              'type' => 'attachment',
              'token' => '{{anexo:catalogo}}',
              'filename' => 'catalogo.png',
              'file_type' => 'image'
            )
          )
        end

        it 'forwards conversation history to ChatService' do
          post "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}/test",
               params: {
                 message: 'segunda',
                 history: [
                   { role: 'user', content: 'primeira' },
                   { role: 'assistant', content: 'resposta' }
                 ]
               },
               headers: auth_headers_for(administrator),
               as: :json

          expect(response).to have_http_status(:success)
          expect(AiAttendant::ChatService).to have_received(:new).with(
            hash_including(
              history: [
                { role: 'user', content: 'primeira' },
                { role: 'assistant', content: 'resposta' }
              ]
            )
          )
        end
      end

      context 'when ChatClient is stubbed' do
        let(:handoff_tool_calls) do
          [
            {
              'id' => 'call_handoff',
              'type' => 'function',
              'function' => {
                'name' => 'handoff_to_human',
                'arguments' => { summary: 'Cliente pediu um humano' }.to_json
              }
            }
          ]
        end

        before do
          allow(AiAttendant::HandoffService).to receive(:new)
          allow(PlatformAi::QuotaGuard).to receive(:charge!)
          allow(PlatformAi::ChatClient).to receive(:complete).and_return(
            { content: nil, tool_calls: handoff_tool_calls, total_tokens: 40 },
            { content: 'Vou te transferir.', tool_calls: [], total_tokens: 60 }
          )
        end

        it 'does not charge quota or run HandoffService' do
          expect do
            post "/api/v1/accounts/#{account.id}/ai_attendant_configs/#{config.id}/test",
                 params: { message: 'oi' },
                 headers: auth_headers_for(administrator),
                 as: :json
          end.not_to change { Message.where(private: false, message_type: :outgoing).count }

          expect(response).to have_http_status(:success)
          expect(json_body['reply']).to be_nil
          expect(json_body['handoff']).to be(true)
          expect(AiAttendant::HandoffService).not_to have_received(:new)
          expect(PlatformAi::QuotaGuard).not_to have_received(:charge!)
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_attendant_configs/import' do
    let(:import_payload) do
      {
        id: 'many-ia-cfg-import',
        inboxId: inbox.id,
        isActive: true,
        nomeAtendenteDigital: 'Lia Import',
        horarioAtendimento: 'Atender 24h por dia'
      }
    end
    let(:agent_api_headers) { { api_access_token: agent.access_token.token } }

    context 'when the user access token is missing' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs/import",
             params: import_payload,
             as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(AiAttendantConfig.count).to eq(0)
      end
    end

    context 'when the user does not belong to the account' do
      it 'returns unauthorized' do
        foreign_agent = create(:user, account: create(:account), role: :agent)

        post "/api/v1/accounts/#{account.id}/ai_attendant_configs/import",
             params: import_payload,
             headers: { api_access_token: foreign_agent.access_token.token },
             as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(AiAttendantConfig.count).to eq(0)
      end
    end

    context 'when the agent access token is valid' do
      it 'creates a config from the many-ia payload' do
        expect do
          post "/api/v1/accounts/#{account.id}/ai_attendant_configs/import",
               params: import_payload,
               headers: agent_api_headers,
               as: :json
        end.to change(AiAttendantConfig, :count).by(1)

        expect(response).to have_http_status(:success)
        created = account.ai_attendant_configs.last
        expect(created.many_ia_config_id).to eq('many-ia-cfg-import')
        expect(created.digital_agent_name).to eq('Lia Import')
        expect(created.schedule_mode).to eq('always')
        expect(created.sender_agent_bot_id).to be_present
        expect(json_body['many_ia_config_id']).to eq('many-ia-cfg-import')
        expect(secret_keys_in(json_body)).to be_empty
      end

      it 'updates the existing config with the same many_ia_config_id' do
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs/import",
             params: import_payload,
             headers: agent_api_headers,
             as: :json

        expect do
          post "/api/v1/accounts/#{account.id}/ai_attendant_configs/import",
               params: import_payload.merge(nomeAtendenteDigital: 'Lia Upsert'),
               headers: agent_api_headers,
               as: :json
        end.not_to change(AiAttendantConfig, :count)

        expect(response).to have_http_status(:success)
        expect(account.ai_attendant_configs.last.digital_agent_name).to eq('Lia Upsert')
        expect(json_body['digital_agent_name']).to eq('Lia Upsert')
      end

      it 'returns unprocessable entity when id is blank' do
        post "/api/v1/accounts/#{account.id}/ai_attendant_configs/import",
             params: import_payload.merge(id: ''),
             headers: agent_api_headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['error']).to match(/id is required/)
        expect(AiAttendantConfig.count).to eq(0)
      end
    end
  end
end

