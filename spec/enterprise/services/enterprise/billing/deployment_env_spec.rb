require 'rails_helper'

RSpec.describe Enterprise::Billing::DeploymentEnv do
  def set_deployment_env(value)
    config = InstallationConfig.find_or_initialize_by(name: 'DEPLOYMENT_ENV')
    config.value = value
    config.save!
  end

  describe '.billing_enabled?' do
    it 'is true for cloud' do
      set_deployment_env('cloud')
      expect(described_class.billing_enabled?).to be(true)
    end

    it 'is true for manytalks' do
      set_deployment_env('manytalks')
      expect(described_class).to be_manytalks
      expect(described_class.billing_enabled?).to be(true)
    end

    it 'is false for self-hosted' do
      set_deployment_env('self-hosted')
      expect(described_class.billing_enabled?).to be(false)
    end
  end
end
