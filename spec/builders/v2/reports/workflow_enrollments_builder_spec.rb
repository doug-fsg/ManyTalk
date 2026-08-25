# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V2::Reports::WorkflowEnrollmentsBuilder do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:workflow) { create(:workflow, account: account, name: 'Follow-up') }
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: admin) }
  let(:since) { 1.week.ago.to_i.to_s }
  let(:until_time) { 1.day.from_now.to_i.to_s }
  let(:params) { { since: since, until: until_time } }

  before { account.enable_features!('workflows') }

  it 'serializes enrollments with contact, assignee and conversation' do
    enrollment = create(
      :workflow_enrollment,
      account: account,
      workflow: workflow,
      conversation: conversation,
      contact: contact,
      started_by: admin,
      status: 'waiting',
      current_node_id: 'action_1'
    )

    result = described_class.new(account: account, user: admin, params: params).build
    row = result[:payload].find { |item| item[:id] == enrollment.id }

    expect(row[:workflow_name]).to eq('Follow-up')
    expect(row[:status]).to eq('waiting')
    expect(row[:conversation_id]).to eq(conversation.display_id)
    expect(row[:conversation_status]).to eq('open')
    expect(row[:contact][:name]).to eq('Maria')
    expect(row[:assigned_agent][:id]).to eq(admin.id)
    expect(row[:started_by][:id]).to eq(admin.id)
    expect(result[:meta][:count]).to eq(1)
  end

  it 'filters by workflow_id' do
    other_workflow = create(:workflow, account: account)
    create(:workflow_enrollment, account: account, workflow: workflow, conversation: conversation, contact: contact)
    create(:workflow_enrollment, account: account, workflow: other_workflow,
                                 conversation: create(:conversation, account: account, inbox: inbox),
                                 contact: contact)

    result = described_class.new(
      account: account,
      user: admin,
      params: params.merge(workflow_id: workflow.id)
    ).build

    expect(result[:payload].map { |row| row[:workflow_id] }.uniq).to eq([workflow.id])
  end
end
