class Enterprise::Billing::StripeLinkChoiceBuilder
  class << self
    def subscription_choices(subscriptions)
      subscriptions.map do |subscription|
        subscription_id = Enterprise::Billing::SubscriptionAttributes.subscription_id(subscription)
        status = Enterprise::Billing::SubscriptionAttributes.status(subscription)

        {
          'id' => subscription_id,
          'label' => [subscription_id, status].join(' · ')
        }
      end
    end

    def subscription_item_choices(subscription)
      Enterprise::Billing::SubscriptionAttributes.items(subscription).map do |item|
        product = item.price&.product
        product_id = product.is_a?(String) ? product : product&.id
        product_label = product.respond_to?(:name) ? product.name : product_id

        {
          'id' => item.id,
          'label' => [
            product_label,
            product_id,
            "qty #{item.quantity}",
            item.price&.id
          ].compact.join(' · ')
        }
      end
    end
  end
end
