# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::TemplateFactory do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe '.available_templates' do
    it 'returns metadata for all templates' do
      templates = described_class.available_templates

      expect(templates.map { |t| t[:key] }).to contain_exactly(
        'follow_up_basic',
        'crm_stage_changed',
        'welcome_conversation'
      )
      expect(templates.first).to include(:name, :description, :category, :trigger_event, :step_count)
    end
  end

  describe '.clone_to_account' do
    it 'creates follow_up_basic with wait_for_reply nodes' do
      workflow = described_class.clone_to_account('follow_up_basic', account: account, user: user)

      node_types = workflow.graph['nodes'].map { |n| n['type'] }
      expect(node_types).to include('wait_for_reply')
      expect(node_types.count('wait_for_reply')).to eq(2)
      expect(workflow.active).to be false
      expect(workflow.graph['nodes'].map { |n| n['x'] }.uniq.size).to be > 1
    end

    it 'creates crm_stage_changed template' do
      workflow = described_class.clone_to_account('crm_stage_changed', account: account, user: user)

      trigger = workflow.graph['nodes'].find { |n| n['type'] == 'trigger' }
      expect(trigger.dig('data', 'event_name')).to eq('contact_kanban_stage_changed')
    end

    it 'creates welcome_conversation template' do
      workflow = described_class.clone_to_account('welcome_conversation', account: account, user: user)

      trigger = workflow.graph['nodes'].find { |n| n['type'] == 'trigger' }
      expect(trigger.dig('data', 'event_name')).to eq('conversation_created')
    end

    it 'raises for unknown template' do
      expect do
        described_class.clone_to_account('unknown', account: account, user: user)
      end.to raise_error(ArgumentError, /Unknown template/)
    end
  end
end
