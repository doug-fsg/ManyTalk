# == Schema Information
#
# Table name: agent_bots
#
#  id           :bigint           not null, primary key
#  bot_config   :jsonb
#  bot_type     :integer          default("webhook")
#  capitao      :boolean          default(FALSE), not null
#  description  :string
#  name         :string
#  outgoing_url :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint
#
# Indexes
#
#  index_agent_bots_on_account_id   (account_id)
#  index_agent_bots_unique_capitao  (capitao) UNIQUE WHERE (capitao IS TRUE)
#

class AgentBot < ApplicationRecord
  include AccessTokenable
  include Avatarable

  has_many :agent_bot_inboxes, dependent: :destroy_async
  has_many :inboxes, through: :agent_bot_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  belongs_to :account, optional: true
  enum bot_type: { webhook: 0, csml: 1 }

  validate :validate_agent_bot_config
  validates :outgoing_url, length: { maximum: Limits::URL_LENGTH_LIMIT }

  before_save :clear_other_capitao_flags, if: :will_save_change_to_capitao?

  scope :capitao, -> { where(capitao: true) }

  def self.capitao_bot
    find_by(capitao: true)
  end

  def available_name
    name
  end

  def push_event_data(inbox = nil)
    {
      id: id,
      name: name,
      avatar_url: avatar_url || inbox&.avatar_url,
      type: 'agent_bot'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      type: 'agent_bot',
      capitao: capitao
    }
  end

  # bot_config schema for Capitão (filled by external tool):
  # {
  #   "agents": [
  #     { "id": "agt_123", "name": "Vendas", "default": true },
  #     { "id": "agt_456", "name": "Suporte" }
  #   ]
  # }
  def capitao_agents
    return [] unless capitao?

    Array(bot_config.is_a?(Hash) ? bot_config['agents'] : nil).filter_map do |agent|
      next unless agent.is_a?(Hash)

      id = agent['id'].presence || agent[:id].presence
      name = agent['name'].presence || agent[:name].presence
      next if id.blank? || name.blank?

      {
        'id' => id.to_s,
        'name' => name.to_s,
        'default' => ActiveModel::Type::Boolean.new.cast(agent['default'] || agent[:default]) || false
      }
    end
  end

  def capitao_default_agent
    agents = capitao_agents
    return if agents.blank?

    selected = agents.find { |agent| agent['default'] } || agents.first
    selected.slice('id', 'name')
  end

  def find_capitao_agent(agent_id)
    return if agent_id.blank?

    agent = capitao_agents.find { |item| item['id'] == agent_id.to_s }
    agent&.slice('id', 'name')
  end

  private

  def clear_other_capitao_flags
    return unless capitao?

    AgentBot.where(capitao: true).where.not(id: id).update_all(capitao: false)
  end

  def validate_agent_bot_config
    errors.add(:bot_config, 'Invalid Bot Configuration') unless AgentBots::ValidateBotService.new(agent_bot: self).perform
  end
end
