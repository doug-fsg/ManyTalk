class Enterprise::Billing::CloudPlans
  def self.all
    Array(InstallationConfig.find_by(name: 'CHATWOOT_CLOUD_PLANS')&.value)
  end

  def self.default_plan
    all.first
  end

  def self.plan_for_product(product_id)
    return if product_id.blank?

    all.find { |config| Array(config['product_id']).include?(product_id) }
  end
end
