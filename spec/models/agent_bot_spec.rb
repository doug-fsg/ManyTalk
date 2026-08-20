require 'rails_helper'
require Rails.root.join 'spec/models/concerns/access_tokenable_shared.rb'
require Rails.root.join 'spec/models/concerns/avatarable_shared.rb'

RSpec.describe AgentBot do
  describe 'associations' do
    it { is_expected.to have_many(:agent_bot_inboxes) }
    it { is_expected.to have_many(:inboxes) }
  end

  describe 'concerns' do
    it_behaves_like 'access_tokenable'
    it_behaves_like 'avatarable'
  end

  context 'when it validates outgoing_url length' do
    let(:agent_bot) { create(:agent_bot) }

    it 'valid when within limit' do
      agent_bot.outgoing_url = 'a' * Limits::URL_LENGTH_LIMIT
      expect(agent_bot.valid?).to be true
    end

    it 'invalid when crossed the limit' do
      agent_bot.outgoing_url = 'a' * (Limits::URL_LENGTH_LIMIT + 1)
      agent_bot.valid?
      expect(agent_bot.errors[:outgoing_url]).to include("is too long (maximum is #{Limits::URL_LENGTH_LIMIT} characters)")
    end
  end

  context 'when agent bot is deleted' do
    let(:agent_bot) { create(:agent_bot) }
    let(:message) { create(:message, sender: agent_bot) }

    it 'nullifies the message sender key' do
      expect(message.sender).to eq agent_bot
      agent_bot.destroy!

      expect(message.reload.sender).to be_nil
    end
  end

  describe 'capitao flag' do
    it 'allows only one capitao bot at a time' do
      first_bot = create(:agent_bot, capitao: true)
      second_bot = create(:agent_bot, capitao: false)

      second_bot.update!(capitao: true)

      expect(first_bot.reload.capitao).to be(false)
      expect(second_bot.reload.capitao).to be(true)
      expect(AgentBot.capitao_bot).to eq(second_bot)
    end
  end

  describe 'capitao agents from bot_config' do
    it 'returns normalized agents and default agent' do
      agent_bot = create(
        :agent_bot,
        capitao: true,
        bot_config: {
          'agents' => [
            { 'id' => 'agt_suporte', 'name' => 'Suporte' },
            { 'id' => 'agt_vendas', 'name' => 'Vendas', 'default' => true }
          ]
        }
      )

      expect(agent_bot.capitao_agents).to contain_exactly(
        { 'id' => 'agt_suporte', 'name' => 'Suporte', 'default' => false },
        { 'id' => 'agt_vendas', 'name' => 'Vendas', 'default' => true }
      )
      expect(agent_bot.capitao_default_agent).to eq({ 'id' => 'agt_vendas', 'name' => 'Vendas' })
      expect(agent_bot.find_capitao_agent('agt_suporte')).to eq({ 'id' => 'agt_suporte', 'name' => 'Suporte' })
    end
  end
end
