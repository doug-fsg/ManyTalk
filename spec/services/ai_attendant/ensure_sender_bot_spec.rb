# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::EnsureSenderBot do
  let(:account) { create(:account) }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      digital_agent_name: 'Lia',
      avatar_id: 'avatar_2'
    )
  end

  describe '.for' do
    it 'creates an agent bot and does not create a user' do
      expect do
        described_class.for(config: config)
      end.to change(AgentBot, :count).by(1).and change(User, :count).by(0)

      bot = config.reload.sender_agent_bot
      expect(bot.name).to eq('Lia')
      expect(bot.account_id).to eq(account.id)
      expect(bot.bot_config['kind']).to eq(AgentBot::AI_ATTENDANT_KIND)
      expect(bot.outgoing_url).to be_nil
      expect(bot.avatar).to be_attached
      expect(account.users.count).to eq(0)
    end

    it 'returns the same bot on a second call' do
      first = described_class.for(config: config)

      expect do
        second = described_class.for(config: config)
        expect(second.id).to eq(first.id)
      end.not_to change(AgentBot, :count)
    end

    it 'updates the display name and avatar when the config changes' do
      bot = described_class.for(config: config)
      config.update!(digital_agent_name: 'Carlos', avatar_id: 'avatar_4')

      described_class.for(config: config.reload)
      bot.reload

      expect(bot.name).to eq('Carlos')
      expect(bot.bot_config['ai_avatar_id']).to eq('avatar_4')
    end
  end
end
