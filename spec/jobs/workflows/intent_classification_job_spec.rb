# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::IntentClassificationJob, type: :job do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:workflow) { create(:workflow, account: account) }
  let(:enrollment) do
    create(:workflow_enrollment,
           workflow: workflow,
           account: account,
           conversation: conversation,
           contact: contact,
           status: 'waiting',
           context: {
             'intent_watch' => {
               'node_id' => 'intent_1',
               'intent_key' => 'menu_request',
               'baseline_at' => 1.hour.ago.iso8601(6),
               'deadline_at' => 1.hour.from_now.iso8601(6),
               'classification_in_flight' => false,
               'seen_normalized' => [],
               'last_classification' => nil
             }
           })
  end
  let(:message) { create(:message, conversation: conversation, message_type: :incoming, content: 'quero o cardápio') }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('WORKFLOW_AI_INTENT_WEBHOOK_URL').and_return('https://example.com/intent')
    allow(account).to receive(:feature_enabled?).with('inteligencia_artificial').and_return(true)
    stub_request(:post, 'https://example.com/intent')
      .to_return(status: 200, body: '{"matched":false}')
  end

  describe '#perform' do
    it 'does nothing when enrollment is gone' do
      expect { described_class.perform_now(999_999, message.id) }.not_to raise_error
    end

    it 'skips when intent_watch is no longer active' do
      enrollment.update!(context: {})
      expect(Workflows::AiWaitForIntentService).not_to receive(:new)
      described_class.perform_now(enrollment.id, message.id)
    end

    it 'skips when same message already classified' do
      enrollment.update!(context: enrollment.context.merge(
        'intent_watch' => enrollment.intent_watch.merge('last_classification' => { 'message_id' => message.id })
      ))
      expect(Workflows::AiWaitForIntentService).not_to receive(:new)
      described_class.perform_now(enrollment.id, message.id)
    end

    it 'skips trivial emoji messages via prefilter without calling AI' do
      emoji_message = create(:message, conversation: conversation, message_type: :incoming, content: '👍')
      expect(Workflows::AiWaitForIntentService).not_to receive(:new)
      described_class.perform_now(enrollment.id, emoji_message.id)
      enrollment.reload
      expect(enrollment.intent_watch.dig('last_classification', 'skipped')).to be true
    end

    context 'when AI returns matched: true' do
      before do
        stub_request(:post, 'https://example.com/intent')
          .to_return(status: 200, body: '{"matched":true}')
      end

      it 'calls on_intent_detected' do
        expect(Workflows::OrchestratorService).to receive(:on_intent_detected).with(enrollment)
        described_class.perform_now(enrollment.id, message.id)
      end
    end

    context 'when AI returns matched: false' do
      it 'does not call on_intent_detected' do
        expect(Workflows::OrchestratorService).not_to receive(:on_intent_detected)
        described_class.perform_now(enrollment.id, message.id)
      end

      it 'records last_classification on the enrollment' do
        described_class.perform_now(enrollment.id, message.id)
        enrollment.reload
        expect(enrollment.intent_watch.dig('last_classification', 'matched')).to be false
      end
    end
  end
end
