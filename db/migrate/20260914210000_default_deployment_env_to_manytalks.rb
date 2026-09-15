class DefaultDeploymentEnvToManytalks < ActiveRecord::Migration[7.0]
  CONFIG_NAME = 'DEPLOYMENT_ENV'.freeze
  LEGACY_DEFAULT = 'self-hosted'.freeze
  TARGET = 'manytalks'.freeze

  def up
    config = InstallationConfig.find_by(name: CONFIG_NAME)
    return if config.blank?

    current_value = config.value.to_s
    return if current_value.present? && current_value != LEGACY_DEFAULT

    config.update!(value: TARGET)
  end

  def down
    config = InstallationConfig.find_by(name: CONFIG_NAME)
    return if config.blank?
    return unless config.value.to_s == TARGET

    config.update!(value: LEGACY_DEFAULT)
  end
end
