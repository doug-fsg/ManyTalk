# frozen_string_literal: true

module AiAttendant
  class EnsureSenderBot
    BOT_NAME = 'Atendente IA'

    def self.for(config:)
      new(config: config).perform
    end

    def initialize(config:)
      @config = config
      @account = config.account
    end

    def perform
      bot = config.sender_agent_bot || create_bot
      sync_profile!(bot)
      config.update!(sender_agent_bot: bot) if config.sender_agent_bot_id != bot.id
      bot
    end

    private

    attr_reader :config, :account

    def display_name
      config.digital_agent_name.presence || BOT_NAME
    end

    def create_bot
      AgentBot.create!(
        account: account,
        name: display_name,
        description: 'Atendente IA. Não é um usuário da conta.',
        bot_type: :webhook,
        outgoing_url: nil,
        bot_config: {
          'kind' => AgentBot::AI_ATTENDANT_KIND,
          'ai_attendant_config_id' => config.id
        }
      )
    end

    def sync_profile!(bot)
      attrs = bot.bot_config.is_a?(Hash) ? bot.bot_config.stringify_keys : {}
      attrs['kind'] = AgentBot::AI_ATTENDANT_KIND
      attrs['ai_attendant_config_id'] = config.id
      bot.name = display_name
      bot.description = 'Atendente IA. Não é um usuário da conta.'
      bot.outgoing_url = nil
      bot.bot_config = attrs
      bot.save! if bot.changed?
      attach_avatar!(bot, attrs)
    end

    def attach_avatar!(bot, attrs)
      path = Avatars.path_for(config.avatar_id)
      return if path.blank? || !File.exist?(path)

      checksum = Digest::MD5.file(path).hexdigest
      return if bot.avatar.attached? && attrs['ai_avatar_checksum'] == checksum &&
                attrs['ai_avatar_id'] == config.avatar_id

      bot.avatar.attach(
        io: File.open(path),
        filename: File.basename(path),
        content_type: 'image/png'
      )
      bot.update!(
        bot_config: attrs.merge(
          'ai_avatar_id' => config.avatar_id,
          'ai_avatar_checksum' => checksum
        )
      )
    end
  end
end
