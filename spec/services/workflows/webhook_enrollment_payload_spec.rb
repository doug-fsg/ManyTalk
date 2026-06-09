# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::WebhookEnrollmentPayload do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before { account.enable_features!('workflows') }

  it 'returns active false when there is no enrollment' do
    payload = described_class.for(conversation)
    expect(payload).to eq(active: false)
  end

  it 'returns active false when workflows feature is disabled' do
    account.disable_features!('workflows')
    create(:workflow_enrollment, workflow: create(:workflow, account: account), conversation: conversation, account: account)

    expect(described_class.for(conversation)).to eq(active: false)
  end

  it 'returns minimal enrollment info when a flow is in progress' do
    workflow = create(
      :workflow,
      account: account,
      name: 'Reengajamento 24h',
      graph: {
        'nodes' => [
          { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'conversation_created', 'conditions' => [] } },
          { 'id' => 'wait_1', 'type' => 'wait', 'data' => { 'duration' => 24, 'unit' => 'hours', 'label' => 'Espera 24h' } }
        ],
        'edges' => [{ 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'wait_1' }],
        'settings' => {}
      }
    )
    enrollment = create(
      :workflow_enrollment,
      workflow: workflow,
      conversation: conversation,
      account: account,
      status: 'waiting',
      current_node_id: 'wait_1'
    )

    payload = described_class.for(conversation)

    expect(payload[:active]).to be true
    expect(payload[:items]).to eq([
                                    {
                                      enrollment_id: enrollment.id,
                                      workflow_id: workflow.id,
                                      name: 'Reengajamento 24h',
                                      status: 'waiting',
                                      step: 'Espera 24h'
                                    }
                                  ])
  end
end
