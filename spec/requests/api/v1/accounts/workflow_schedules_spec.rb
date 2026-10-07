# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::WorkflowSchedules' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_headers) { agent.create_new_auth_token.except('Authorization') }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }

  before { account.enable_features!('workflows') }

  def schedule_params(**overrides)
    {
      name: 'Quarta na proposta',
      workflow_id: workflow.id,
      pipeline_id: pipeline.id,
      stage_id: 'Estágio 1',
      weekday: 3,
      hour: 9,
      minute: 0,
      time_zone: 'America/Sao_Paulo',
      active: false
    }.merge(overrides)
  end

  describe 'GET /api/v1/accounts/:account_id/workflow_schedules' do
    it 'lists schedules for the account' do
      create(:workflow_schedule, account: account, workflow: workflow, pipeline: pipeline)

      get "/api/v1/accounts/#{account.id}/workflow_schedules",
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].length).to eq(1)
      expect(response.parsed_body['payload'].first).to include('audience_count', 'recurring')
    end

    it 'returns unauthorized without auth' do
      get "/api/v1/accounts/#{account.id}/workflow_schedules", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/workflow_schedules' do
    it 'creates a weekly schedule' do
      expect do
        post "/api/v1/accounts/#{account.id}/workflow_schedules",
             params: schedule_params,
             headers: agent_headers,
             as: :json
      end.to change(WorkflowSchedule, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']['weekday']).to eq(3)
    end

    it 'rejects a stage that does not exist' do
      post "/api/v1/accounts/#{account.id}/workflow_schedules",
           params: schedule_params(stage_id: 'Nope'),
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/workflow_schedules/:id/toggle_active' do
    it 'activates a schedule when the workflow is active' do
      schedule = create(:workflow_schedule, account: account, workflow: workflow, pipeline: pipeline, active: false)

      post "/api/v1/accounts/#{account.id}/workflow_schedules/#{schedule.id}/toggle_active",
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(schedule.reload.active).to be(true)
    end

    it 'toggles schedules on pipelines with nested kanban stage metadata' do
      pipeline.update!(
        attribute_values: {
          'stages' => {
            'Novo' => { 'color' => '#6554C0' },
            'Proposta' => { 'color' => '#0442C2' }
          },
          'permissions' => {},
          'stage_order' => %w[Novo Proposta]
        }
      )
      schedule = create(
        :workflow_schedule,
        account: account,
        workflow: workflow,
        pipeline: pipeline,
        stage_id: 'Proposta',
        active: true
      )

      post "/api/v1/accounts/#{account.id}/workflow_schedules/#{schedule.id}/toggle_active",
           headers: agent_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(schedule.reload.active).to be(false)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/workflow_schedules/audience_count' do
    it 'counts contacts currently on the stage' do
      contact = create(:contact, account: account)
      create(:contact_pipeline_position, contact: contact, pipeline: pipeline, stage_id: 'Estágio 1')

      get "/api/v1/accounts/#{account.id}/workflow_schedules/audience_count",
          params: { pipeline_id: pipeline.id, stage_id: 'Estágio 1' },
          headers: agent_headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['count']).to eq(1)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/workflow_schedules/:id' do
    it 'destroys the schedule' do
      schedule = create(:workflow_schedule, account: account, workflow: workflow, pipeline: pipeline)

      expect do
        delete "/api/v1/accounts/#{account.id}/workflow_schedules/#{schedule.id}",
               headers: agent_headers,
               as: :json
      end.to change(WorkflowSchedule, :count).by(-1)
    end
  end
end
