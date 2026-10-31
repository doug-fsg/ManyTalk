# frozen_string_literal: true

module AiAttendant
  class EnsureSenderUser
    BOT_NAME = 'Funcionário digital'

    def self.for(config:)
      new(config: config).perform
    end

    def initialize(config:)
      @config = config
      @account = config.account
    end

    def perform
      user = User.from_email(email) || create_user
      ensure_account_membership!(user)
      sync_profile!(user)
      user
    end

    private

    attr_reader :config, :account

    def email
      "funcionario-digital-#{account.id}-config-#{config.id}@manytalks.internal"
    end

    def display_name
      config.digital_agent_name.presence || BOT_NAME
    end

    def create_user
      temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
      user = User.new(
        email: email,
        name: display_name,
        password: temp_password,
        password_confirmation: temp_password
      )
      user.skip_confirmation!
      user.save!
      user
    end

    def ensure_account_membership!(user)
      account_user = AccountUser.find_or_initialize_by(account: account, user: user)
      account_user.role = :administrator
      account_user.save! if account_user.new_record? || account_user.changed?
    end

    def sync_profile!(user)
      user.update!(name: display_name) if user.name != display_name
      attach_avatar!(user)
    end

    def attach_avatar!(user)
      path = Avatars.path_for(config.avatar_id)
      return if path.blank? || !File.exist?(path)

      checksum = Digest::MD5.file(path).hexdigest
      attrs = user.custom_attributes.is_a?(Hash) ? user.custom_attributes.stringify_keys : {}
      return if user.avatar.attached? && attrs['ai_avatar_checksum'] == checksum &&
                attrs['ai_avatar_id'] == config.avatar_id

      user.avatar.attach(
        io: File.open(path),
        filename: File.basename(path),
        content_type: 'image/png'
      )
      user.update!(
        custom_attributes: attrs.merge(
          'ai_avatar_id' => config.avatar_id,
          'ai_avatar_checksum' => checksum
        )
      )
    end
  end
end
