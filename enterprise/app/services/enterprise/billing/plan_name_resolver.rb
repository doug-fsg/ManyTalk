class Enterprise::Billing::PlanNameResolver
  class << self
    def resolve(product_id, fallback_name: nil, product_name: nil, fetch_from_stripe: true)
      return fallback_name if product_id.blank? && fallback_name.present?
      return if product_id.blank?

      if product_name.present?
        return product_name
      end

      if Enterprise::Billing::DeploymentEnv.manytalks?
        return fallback_name if fallback_name.present? && !fetch_from_stripe

        manytalks_plan_name(product_id, fallback_name: fallback_name, fetch_from_stripe: fetch_from_stripe)
      else
        Enterprise::Billing::CloudPlans.plan_for_product(product_id)&.dig('name')
      end
    end

    private

    def manytalks_plan_name(product_id, fallback_name:, fetch_from_stripe:)
      return fallback_name if fallback_name.present? && !fetch_from_stripe

      Stripe::Product.retrieve(product_id).name.presence || fallback_name.presence || product_id
    rescue Stripe::StripeError
      fallback_name.presence || product_id
    end
  end
end
