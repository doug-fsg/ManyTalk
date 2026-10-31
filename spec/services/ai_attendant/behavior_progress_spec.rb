# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::BehaviorProgress do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      inbox_id: inbox.id,
      behavior_step_mode: 'strict',
      behavior_steps: [
        { 'instruction' => 'Passo 1', 'completion_criterion' => '' },
        { 'instruction' => 'Passo 2', 'completion_criterion' => '' }
      ]
    )
  end
  let(:script) { AiAttendant::BehaviorScript.from_config(config) }

  describe '.advance!' do
    it 'increments step index for the same conversation' do
      result = described_class.advance!(
        contact: contact,
        conversation: conversation,
        script: script,
        evidence: 'Cliente disse oi'
      )

      expect(result[:ok]).to be(true)
      expect(result[:previous_index]).to eq(0)
      expect(result[:current_index]).to eq(1)

      progress = described_class.load(contact: contact, conversation: conversation)
      expect(progress.step_index).to eq(1)
    end

    it 'resets when conversation_id changes' do
      described_class.advance!(
        contact: contact,
        conversation: conversation,
        script: script,
        evidence: 'ok'
      )

      other_conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      progress = described_class.load(contact: contact, conversation: other_conversation)
      expect(progress.step_index).to eq(0)
    end
  end
end
