# frozen_string_literal: true

class SwitchAiAttendantSenderToAgentBot < ActiveRecord::Migration[7.0]
  SYNTHETIC_EMAIL = /\Afuncionario-digital-\d+-config-\d+@manytalks\.internal\z/

  def up
    add_reference :ai_attendant_configs, :sender_agent_bot, foreign_key: { to_table: :agent_bots }, index: true

    AiAttendantConfig.reset_column_information
    AiAttendantConfig.find_each do |config|
      user_id = config.read_attribute('sender_user_id')
      bot = AiAttendant::EnsureSenderBot.for(config: config)
      retire_synthetic_user!(user_id, bot.id)
    end

    remove_reference :ai_attendant_configs, :sender_user, foreign_key: { to_table: :users }, index: true
  end

  def down
    add_reference :ai_attendant_configs, :sender_user, foreign_key: { to_table: :users }, index: true
    remove_reference :ai_attendant_configs, :sender_agent_bot, foreign_key: { to_table: :agent_bots }, index: true
  end

  private

  def retire_synthetic_user!(user_id, bot_id)
    return if user_id.blank?

    user = User.find_by(id: user_id)
    return if user.blank? || !SYNTHETIC_EMAIL.match?(user.email.to_s)

    Message.where(sender_type: 'User', sender_id: user.id).update_all(sender_type: 'AgentBot', sender_id: bot_id)
    user.account_users.destroy_all
    user.destroy!
  end
end
