# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contacts::KanbanOwnershipSyncService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:custom_attribute_definition, :kanban, account: account) }
  let(:position) do
    create(
      :contact_pipeline_position,
      contact: contact,
      pipeline: pipeline,
      assignee: agent
    )
  end

  def set_ownership_mode(mode)
    values = pipeline.attribute_values
    values = { 'stages' => {}, 'permissions' => {}, 'stage_order' => [] } unless values.is_a?(Hash)
    pipeline.update!(attribute_values: values.merge('ownership_mode' => mode))
  end

  describe '#resolve_primary_conversation' do
    it 'usa a conversa aberta mais recente quando não há seleção' do
      older = create(:conversation, account: account, contact: contact, last_activity_at: 2.days.ago)
      newer = create(:conversation, account: account, contact: contact, last_activity_at: 1.hour.ago)
      create(:conversation, account: account, contact: contact, status: :resolved, last_activity_at: Time.current)

      resolved = described_class.new(position).resolve_primary_conversation

      expect(resolved).to eq(newer)
      expect(resolved).not_to eq(older)
    end

    it 'respeita a conversa salva no metadata quando ela ainda está ativa' do
      selected = create(:conversation, account: account, contact: contact, status: :pending, last_activity_at: 3.days.ago)
      create(:conversation, account: account, contact: contact, last_activity_at: Time.current)
      position.update!(metadata: { 'primary_conversation_id' => selected.display_id })

      expect(described_class.new(position).resolve_primary_conversation).to eq(selected)
    end

    it 'ignora a conversa salva se ela já foi resolvida' do
      resolved_conversation = create(:conversation, account: account, contact: contact, status: :resolved)
      fallback = create(:conversation, account: account, contact: contact, status: :open, last_activity_at: Time.current)
      position.update!(metadata: { 'primary_conversation_id' => resolved_conversation.display_id })

      expect(described_class.new(position).resolve_primary_conversation).to eq(fallback)
    end
  end

  describe '.sync_pipeline_assignee_to_conversation' do
    it 'copia o responsável do card para a conversa no modo único' do
      set_ownership_mode('linked')
      conversation = create(:conversation, account: account, contact: contact, assignee: nil)

      described_class.sync_pipeline_assignee_to_conversation(position)

      expect(conversation.reload.assignee_id).to eq(agent.id)
    end

    it 'não altera a conversa no modo separado' do
      set_ownership_mode('split')
      conversation = create(:conversation, account: account, contact: contact, assignee: nil)

      described_class.sync_pipeline_assignee_to_conversation(position)

      expect(conversation.reload.assignee_id).to be_nil
    end
  end

  describe '.sync_owner_from_primary_conversation' do
    it 'copia o atendente da conversa escolhida para o dono do card no modo único' do
      set_ownership_mode('linked')
      selected = create(:conversation, account: account, contact: contact, assignee: other_agent)
      position.update!(metadata: { 'primary_conversation_id' => selected.display_id })

      described_class.sync_owner_from_primary_conversation(position)

      expect(position.reload.assignee_id).to eq(other_agent.id)
      expect(selected.reload.assignee_id).to eq(other_agent.id)
    end

    it 'não altera o dono do card no modo separado' do
      set_ownership_mode('split')
      selected = create(:conversation, account: account, contact: contact, assignee: other_agent)
      position.update!(metadata: { 'primary_conversation_id' => selected.display_id })

      described_class.sync_owner_from_primary_conversation(position)

      expect(position.reload.assignee_id).to eq(agent.id)
    end
  end

  describe '.sync_conversation_assignee_to_pipelines' do
    it 'atualiza apenas pipelines no modo único' do
      set_ownership_mode('linked')
      position
      split_pipeline = create(:custom_attribute_definition, :kanban, account: account)
      split_values = { 'stages' => {}, 'permissions' => {}, 'stage_order' => [], 'ownership_mode' => 'split' }
      split_pipeline.update!(attribute_values: split_values)
      split_position = create(
        :contact_pipeline_position,
        contact: contact,
        pipeline: split_pipeline,
        assignee: agent
      )
      conversation = create(:conversation, account: account, contact: contact, assignee: other_agent)

      described_class.sync_conversation_assignee_to_pipelines(conversation)

      expect(position.reload.assignee_id).to eq(other_agent.id)
      expect(split_position.reload.assignee_id).to eq(agent.id)
    end

    it 'não reentra no sync da conversa ao atualizar o card' do
      set_ownership_mode('linked')
      conversation = create(:conversation, account: account, contact: contact, assignee: other_agent)
      allow(described_class).to receive(:sync_pipeline_assignee_to_conversation).and_call_original

      described_class.sync_conversation_assignee_to_pipelines(conversation)

      expect(described_class).not_to have_received(:sync_pipeline_assignee_to_conversation)
      expect(conversation.reload.assignee_id).to eq(other_agent.id)
    end
  end
end
