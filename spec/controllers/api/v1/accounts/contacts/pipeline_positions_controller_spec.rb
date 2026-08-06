# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pipeline Positions API', type: :request do
  let!(:account) { create(:account) }
  let!(:contact) { create(:contact, account: account) }
  let!(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:other_agent) { create(:user, account: account, role: :agent) }

  describe 'PATCH /api/v1/accounts/:account_id/contacts/:contact_id/pipeline_positions/:pipeline_id' do
    let(:url) do
      "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/pipeline_positions/#{pipeline.id}"
    end

    context 'when it is an authenticated user' do
      it 'creates a pipeline position for the contact' do
        patch url,
              params: { stage_id: 'Estágio 1', position: 0 },
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:pipeline_id]).to eq(pipeline.id)
        expect(body[:stage_id]).to eq('Estágio 1')
        expect(contact.contact_pipeline_positions.find_by(pipeline_id: pipeline.id)).to be_present
      end

      it 'updates an existing pipeline position instead of creating a duplicate' do
        create(
          :contact_pipeline_position,
          contact: contact,
          pipeline: pipeline,
          stage_id: 'Estágio 1',
          position: 0
        )

        patch url,
              params: { stage_id: 'Estágio 2', position: 1 },
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:stage_id]).to eq('Estágio 2')
        expect(body[:position]).to eq(1)
        expect(contact.contact_pipeline_positions.where(pipeline_id: pipeline.id).count).to eq(1)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/contacts/pipeline_positions/:pipeline_id/stats' do
    let(:stats_url) do
      "/api/v1/accounts/#{account.id}/contacts/pipeline_positions/#{pipeline.id}/stats"
    end
    let!(:own_contact) { create(:contact, account: account) }
    let!(:unassigned_contact) { create(:contact, account: account) }
    let!(:other_contact) { create(:contact, account: account) }

    before do
      pipeline.set_user_permission(agent.id, 'editor')

      create(
        :contact_pipeline_position,
        contact: own_contact,
        pipeline: pipeline,
        stage_id: 'Estágio 1',
        assignee: agent,
        deal_value: 100
      )
      create(
        :contact_pipeline_position,
        contact: unassigned_contact,
        pipeline: pipeline,
        stage_id: 'Estágio 1',
        assignee: nil,
        deal_value: 50
      )
      create(
        :contact_pipeline_position,
        contact: other_contact,
        pipeline: pipeline,
        stage_id: 'Estágio 1',
        assignee: other_agent,
        deal_value: 200
      )
    end

    it 'returns all stage counts for administrators' do
      get stats_url, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body, symbolize_names: true)
      stage = body[:stage_stats].find { |stat| stat[:stage_id] == 'Estágio 1' }
      expect(stage[:count]).to eq(3)
      expect(stage[:total_value]).to eq(350.0)
    end

    it 'returns only own and unassigned counts for agents' do
      get stats_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body, symbolize_names: true)
      stage = body[:stage_stats].find { |stat| stat[:stage_id] == 'Estágio 1' }
      expect(stage[:count]).to eq(2)
      expect(stage[:total_value]).to eq(150.0)
    end
  end
end
