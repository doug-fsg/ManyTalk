# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ListMetricsService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:workflow) { create(:workflow, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    account.enable_features!('workflows')
  end

  it 'returns default metrics when no enrollments exist' do
    result = described_class.new(
      account: account,
      user: admin,
      workflow_ids: [workflow.id]
    ).build

    expect(result[workflow.id]).to eq(active_count: 0, reply_rate_30d: nil)
  end

  it 'counts active enrollments for administrator' do
    conversation = create(:conversation, account: account, inbox: inbox)
    create(:workflow_enrollment, account: account, workflow: workflow, conversation: conversation, status: 'active')

    result = described_class.new(
      account: account,
      user: admin,
      workflow_ids: [workflow.id]
    ).build

    expect(result[workflow.id][:active_count]).to eq(1)
  end

  it 'scopes active enrollments to assigned inboxes for agents' do
    other_inbox = create(:inbox, account: account)
    visible_conversation = create(:conversation, account: account, inbox: inbox)
    hidden_conversation = create(:conversation, account: account, inbox: other_inbox)

    create(:workflow_enrollment, account: account, workflow: workflow, conversation: visible_conversation, status: 'active')
    create(:workflow_enrollment, account: account, workflow: workflow, conversation: hidden_conversation, status: 'active')

    result = described_class.new(
      account: account,
      user: agent,
      workflow_ids: [workflow.id]
    ).build

    expect(result[workflow.id][:active_count]).to eq(1)
  end
end
