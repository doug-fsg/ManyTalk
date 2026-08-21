# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Workflow activity message actors' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let(:workflow) { create(:workflow, account: account, name: 'Follow-up 24h') }

  after { Current.reset }

  it 'uses workflow name on status change activity' do
    Current.executed_by = workflow

    expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
      conversation,
      hash_including(content: a_string_including('Follow-up 24h'))
    )

    conversation.resolved!
  end

  it 'uses workflow name on priority change activity' do
    Current.executed_by = workflow

    expect(Conversations::ActivityMessageJob).to receive(:perform_later).with(
      conversation,
      hash_including(content: a_string_including('Follow-up 24h'))
    )

    conversation.update!(priority: 'high')
  end

  it 'uses workflow name on mute activity' do
    Current.executed_by = workflow

    expect(Conversations::ActivityMessageJob).to receive(:perform_later).at_least(:once)

    conversation.mute!
  end
end
