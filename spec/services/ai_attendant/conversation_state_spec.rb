# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ConversationState do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '.reset!' do
    it 'clears handoff and behavior progress' do
      conversation.update!(
        additional_attributes: {
          'ai_handoff_at' => Time.current.iso8601,
          'ai_behavior_progress' => { 'step_index' => 2 },
          'other' => 'keep'
        }
      )

      described_class.reset!(conversation)

      attributes = conversation.reload.additional_attributes
      expect(attributes).not_to have_key('ai_handoff_at')
      expect(attributes).not_to have_key('ai_behavior_progress')
      expect(attributes['other']).to eq('keep')
    end
  end
end
