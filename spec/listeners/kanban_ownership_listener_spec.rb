# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KanbanOwnershipListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }
  let!(:position) do
    create(:contact_pipeline_position, contact: contact, pipeline: pipeline, assignee: nil)
  end
  let(:conversation) { create(:conversation, account: account, contact: contact, assignee: agent) }

  it 'espelha o atendente no card quando o pipeline é de responsável único' do
    event = Events::Base.new(
      'conversation.updated',
      Time.zone.now,
      conversation: conversation,
      changed_attributes: { 'assignee_id' => [nil, agent.id] }
    )

    listener.conversation_updated(event)

    expect(position.reload.assignee_id).to eq(agent.id)
  end

  it 'ignora a atualização quando o pipeline separa os responsáveis' do
    pipeline.update!(
      attribute_values: {
        'stages' => {},
        'permissions' => {},
        'stage_order' => [],
        'ownership_mode' => 'split'
      }
    )
    event = Events::Base.new(
      'conversation.updated',
      Time.zone.now,
      conversation: conversation,
      changed_attributes: { 'assignee_id' => [nil, agent.id] }
    )

    listener.conversation_updated(event)

    expect(position.reload.assignee_id).to be_nil
  end

  it 'ignora eventos sem mudança de atendente' do
    event = Events::Base.new(
      'conversation.updated',
      Time.zone.now,
      conversation: conversation,
      changed_attributes: { 'status' => %w[pending open] }
    )

    listener.conversation_updated(event)

    expect(position.reload.assignee_id).to be_nil
  end
end
