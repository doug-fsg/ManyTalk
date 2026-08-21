# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ActionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:workflow) { create(:workflow, account: account, name: 'Follow-up 24h') }
  let(:service) { described_class.new(workflow, account, conversation, node_id: 'action_1') }

  after { Current.reset }

  it 'logs webhook activity after sending' do
    expect(WebhookJob).to receive(:perform_later)
    expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
      conversation,
      hash_including(content: a_string_including('Follow-up 24h'))
    )

    expect(service.perform_action('send_webhook_event', ['https://example.com/hook'])).to be(true)
  end

  it 'uses workflow name for kanban activity' do
    pipeline = create(:custom_attribute_definition, :kanban, account: account)
    stage = Array(pipeline.attribute_values).first
    stage_name = stage.is_a?(Hash) ? (stage['name'] || stage[:name]) : stage.to_s

    expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
      conversation,
      hash_including(content: a_string_including('Follow-up 24h').and(including(stage_name)))
    )

    service.perform_action('change_kanban_stage', [pipeline.id, stage_name])
  end
end
