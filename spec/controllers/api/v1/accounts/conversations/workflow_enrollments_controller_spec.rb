# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversations::WorkflowEnrollments API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
        { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'duration' => 6, 'unit' => 'hours' } },
        { 'id' => 'action_1', 'type' => 'action', 'data' => { 'action_name' => 'send_message', 'action_params' => ['Hello'] } }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'wait_1' },
        { 'id' => 'e2', 'source' => 'wait_1', 'target' => 'action_1' }
      ],
      'settings' => Workflows::Constants::DEFAULT_SETTINGS
    }
  end
  let(:workflow) { create(:workflow, account: account, graph: graph, active: true) }

  before do
    account.enable_features!('workflows')
    create(:inbox_member, inbox: inbox, user: agent)
    allow(Workflows::EnrollmentBroadcaster).to receive(:updated)
  end

  describe 'POST /api/v1/accounts/:account_id/conversations/:conversation_id/workflow_enrollments' do
    let(:url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments" }

    context 'when unauthenticated' do
      it 'returns 401' do
        post url, params: { workflow_id: workflow.id }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before { allow(Workflows::OrchestratorService).to receive(:advance_from_node) }

      it 'creates an enrollment' do
        post url,
             headers: agent.create_new_auth_token,
             params: { workflow_id: workflow.id },
             as: :json

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body['workflow_id']).to eq(workflow.id)
        expect(body['status']).to eq('active')
      end

      it 'returns 409 for duplicate enrollment' do
        create(:workflow_enrollment, account: account, conversation: conversation, workflow: workflow, status: 'active')

        post url,
             headers: agent.create_new_auth_token,
             params: { workflow_id: workflow.id },
             as: :json

        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/conversations/:conversation_id/workflow_enrollments/active' do
    let(:url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/active" }

    context 'when unauthenticated' do
      it 'returns 401' do
        get url, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns the active enrollment' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: workflow, status: 'waiting')

        get url, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['id']).to eq(enrollment.id)
        expect(body['status']).to eq('waiting')
      end

      it 'returns null enrollment when none active' do
        get url, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['enrollment']).to be_nil
      end

      it 'excludes completed enrollments' do
        create(:workflow_enrollment, account: account, conversation: conversation,
                                     workflow: workflow, status: 'completed')

        get url, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['enrollment']).to be_nil
      end
    end
  end

  describe 'POST .../workflow_enrollments/:id/pause' do
    context 'when authenticated' do
      it 'pauses the enrollment' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: workflow, status: 'waiting')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/#{enrollment.id}/pause",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['status']).to eq('paused')
      end

      it 'returns 422 for invalid transition' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: create(:workflow, account: account), status: 'completed')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/#{enrollment.id}/pause",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST .../workflow_enrollments/:id/resume' do
    context 'when authenticated' do
      it 'resumes the enrollment' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: workflow, status: 'paused',
                                                  current_node_id: 'action_1')
        allow(Workflows::OrchestratorService).to receive(:advance_from_node)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/#{enrollment.id}/resume",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['status']).to eq('active')
      end
    end
  end

  describe 'POST .../workflow_enrollments/:id/cancel' do
    context 'when authenticated' do
      it 'cancels the enrollment' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: workflow, status: 'active')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/#{enrollment.id}/cancel",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['status']).to eq('cancelled')
      end
    end
  end

  describe 'POST .../workflow_enrollments/:id/jump' do
    context 'when authenticated' do
      it 'jumps to the specified node' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: workflow, status: 'paused',
                                                  current_node_id: 'wait_1')
        allow(Workflows::OrchestratorService).to receive(:advance_from_node)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/#{enrollment.id}/jump",
             headers: agent.create_new_auth_token,
             params: { node_id: 'action_1' },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['current_node_id']).to eq('action_1')
      end

      it 'returns 422 for non-existent node' do
        enrollment = create(:workflow_enrollment, account: account, conversation: conversation,
                                                  workflow: workflow, status: 'active')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/workflow_enrollments/#{enrollment.id}/jump",
             headers: agent.create_new_auth_token,
             params: { node_id: 'nonexistent' },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
