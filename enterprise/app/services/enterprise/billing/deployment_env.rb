class Enterprise::Billing::DeploymentEnv
  CONFIG_NAME = 'DEPLOYMENT_ENV'.freeze

  CLOUD = 'cloud'.freeze
  MANYTALKS = 'manytalks'.freeze
  SELF_HOSTED = 'self-hosted'.freeze

  BILLING_ENABLED = [CLOUD, MANYTALKS].freeze

  def self.value
    InstallationConfig.find_by(name: CONFIG_NAME)&.value.to_s
  end

  def self.cloud?
    value == CLOUD
  end

  def self.manytalks?
    value == MANYTALKS
  end

  def self.billing_enabled?
    BILLING_ENABLED.include?(value)
  end
end
