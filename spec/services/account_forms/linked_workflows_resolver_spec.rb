# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::LinkedWorkflowsResolver do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:account_form) { create(:account_form, :published, account: account) }
  let(:other_form) { create(:account_form, :published, account: account) }

  def form_trigger_data(form_ids:, inbox_id: inbox.id)
    {
      'event_name' => 'form_submitted',
      'inbox_id' => inbox_id,
      'conditions' => [
        {
          'attribute_key' => 'account_form_id',
          'filter_operator' => 'equal_to',
          'values' => Array(form_ids).map(&:to_s)
        }
      ]
    }
  end

  def build_graph(trigger_data, manual_only: false)
    settings = Workflows::Constants::DEFAULT_SETTINGS.merge(
      'allow_manual_start_only' => manual_only
    )
    {
      'nodes' => [
        {
          'id' => 'trigger_1',
          'type' => 'trigger',
          'data' => trigger_data
        }
      ],
      'edges' => [],
      'settings' => settings
    }
  end

  def create_form_workflow!(form_ids:, active: true, manual_only: false)
    create(
      :workflow,
      account: account,
      active: active,
      trigger_event_name: 'form_submitted',
      graph: build_graph(form_trigger_data(form_ids: form_ids), manual_only: manual_only)
    )
  end

  describe '.build' do
    it 'returns contact_only linkage for forms without workflows' do
      result = described_class.build(account: account, form_ids: [account_form.id])

      expect(result[account_form.id]).to eq([])
      expect(described_class.linkage_state(result[account_form.id])).to eq('contact_only')
    end

    it 'links an active workflow as automates' do
      workflow = create_form_workflow!(form_ids: [account_form.id], active: true)
      result = described_class.build(account: account, form_ids: [account_form.id])

      expect(result[account_form.id]).to contain_exactly(
        hash_including(id: workflow.id, name: workflow.name, active: true, manual_only: false)
      )
      expect(described_class.linkage_state(result[account_form.id])).to eq('automates')
    end

    it 'links an inactive workflow as paused_flow' do
      workflow = create_form_workflow!(form_ids: [account_form.id], active: false)
      result = described_class.build(account: account, form_ids: [account_form.id])

      expect(result[account_form.id]).to contain_exactly(
        hash_including(id: workflow.id, active: false)
      )
      expect(described_class.linkage_state(result[account_form.id])).to eq('paused_flow')
    end

    it 'treats active manual-only workflows as paused_flow' do
      create_form_workflow!(form_ids: [account_form.id], active: true, manual_only: true)
      result = described_class.build(account: account, form_ids: [account_form.id])

      expect(described_class.linkage_state(result[account_form.id])).to eq('paused_flow')
    end

    it 'prefers automates when at least one linked workflow effectively automates' do
      create_form_workflow!(form_ids: [account_form.id], active: false)
      create_form_workflow!(form_ids: [account_form.id], active: true)
      result = described_class.build(account: account, form_ids: [account_form.id])

      expect(result[account_form.id].size).to eq(2)
      expect(described_class.linkage_state(result[account_form.id])).to eq('automates')
    end

    it 'ignores workflows with other trigger events' do
      create(
        :workflow,
        account: account,
        active: true,
        trigger_event_name: 'conversation_created',
        graph: build_graph(
          {
            'event_name' => 'conversation_created',
            'conditions' => []
          }
        )
      )

      result = described_class.build(account: account, form_ids: [account_form.id])
      expect(result[account_form.id]).to eq([])
    end

    it 'does not include workflows linked to other forms' do
      create_form_workflow!(form_ids: [other_form.id], active: true)
      result = described_class.build(account: account, form_ids: [account_form.id])

      expect(result[account_form.id]).to eq([])
      expect(result.key?(other_form.id)).to be(false)
    end
  end
end
