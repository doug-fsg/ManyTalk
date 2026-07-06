# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::WorkflowTriggerService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, email: 'lead@example.com') }
  let(:account_form) { create(:account_form, :published, account: account) }
  let(:other_form) { create(:account_form, :published, account: account) }
  let(:submission) do
    FormSubmission.create!(
      account: account,
      account_form: account_form,
      contact: contact,
      payload: { 'email' => 'lead@example.com', 'name' => 'Lead' }
    )
  end

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

  def build_graph(trigger_data)
    {
      'nodes' => [
        {
          'id' => 'trigger_1',
          'type' => 'trigger',
          'data' => trigger_data
        },
        {
          'id' => 'action_1',
          'type' => 'action',
          'data' => { 'action_name' => 'add_label', 'action_params' => ['form-lead'] }
        }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'action_1' }
      ],
      'settings' => Workflows::Constants::DEFAULT_SETTINGS
    }
  end

  def create_form_workflow!(trigger_data)
    create(
      :workflow,
      account: account,
      active: true,
      trigger_event_name: 'form_submitted',
      graph: build_graph(trigger_data)
    )
  end

  before do
    account.enable_features!('workflows')
    allow(Workflows::OrchestratorService).to receive(:advance_from_node)
  end

  def call_service
    described_class.call(
      account_id: account.id,
      contact_id: contact.id,
      account_form_id: account_form.id,
      submission_id: submission.id
    )
  end

  describe '.call' do
    context 'when contact has an open conversation' do
      let!(:conversation) do
        contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
        create(
          :conversation,
          account: account,
          inbox: inbox,
          contact: contact,
          contact_inbox: contact_inbox,
          status: :open
        )
      end

      before do
        create_form_workflow!(form_trigger_data(form_ids: [account_form.id]))
      end

      it 'enrolls in the existing conversation and links the submission' do
        expect { call_service }.to change(WorkflowEnrollment, :count).by(1)

        enrollment = WorkflowEnrollment.last
        expect(enrollment.conversation_id).to eq(conversation.id)
        expect(submission.reload.conversation_id).to eq(conversation.id)
      end
    end

    context 'when contact has no open conversation and trigger has inbox_id' do
      before do
        create_form_workflow!(form_trigger_data(form_ids: [account_form.id]))
      end

      it 'creates a conversation in the configured inbox and enrolls' do
        expect { call_service }
          .to change(Conversation, :count).by(1)
          .and change(WorkflowEnrollment, :count).by(1)

        new_conversation = Conversation.order(:id).last
        expect(new_conversation.inbox_id).to eq(inbox.id)
        expect(new_conversation.contact_id).to eq(contact.id)
        expect(submission.reload.conversation_id).to eq(new_conversation.id)
      end
    end

    context 'when submitted form is not in trigger selection' do
      before do
        create_form_workflow!(form_trigger_data(form_ids: [other_form.id]))
      end

      it 'does not enroll' do
        expect { call_service }.not_to change(WorkflowEnrollment, :count)
      end
    end

    context 'when trigger has no form conditions' do
      before do
        create_form_workflow!(
          'event_name' => 'form_submitted',
          'inbox_id' => inbox.id,
          'conditions' => []
        )
      end

      it 'does not enroll' do
        expect { call_service }.not_to change(WorkflowEnrollment, :count)
      end
    end

    context 'when workflows feature is disabled' do
      before do
        account.disable_features!('workflows')
        create_form_workflow!(form_trigger_data(form_ids: [account_form.id]))
        create(:conversation, account: account, inbox: inbox, contact: contact, status: :open)
      end

      it 'does not enroll' do
        expect { call_service }.not_to change(WorkflowEnrollment, :count)
      end
    end
  end
end
