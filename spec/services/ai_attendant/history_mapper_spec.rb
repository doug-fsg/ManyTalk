# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::HistoryMapper do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:bot) { create(:agent_bot) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe '.call' do
    it 'maps incoming as user, bot as assistant and human agent as labeled user' do
      incoming = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :incoming,
        content: 'Quero prazo'
      )
      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :outgoing,
        sender: bot,
        content: 'Qual produto?'
      )
      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :outgoing,
        sender: agent,
        content: 'O prazo é 10 dias.'
      )
      current = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :incoming,
        content: 'E o preço?'
      )

      history = described_class.call(conversation: conversation, exclude_ids: [current.id])

      expect(history).to eq(
        [
          { role: 'user', content: 'Quero prazo' },
          { role: 'assistant', content: 'Qual produto?' },
          { role: 'user', content: "#{described_class::HUMAN_PREFIX}\nO prazo é 10 dias." }
        ]
      )
      expect(incoming).to be_persisted
    end
  end
end
