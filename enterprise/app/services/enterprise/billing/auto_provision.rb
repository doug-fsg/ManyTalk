class Enterprise::Billing::AutoProvision
  CONFIG_NAME = 'STRIPE_AUTO_PROVISION_CUSTOMERS'.freeze

  def self.enabled?
    ActiveModel::Type::Boolean.new.cast(
      InstallationConfig.find_by(name: CONFIG_NAME)&.value
    )
  end
end
