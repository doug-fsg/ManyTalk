class Enterprise::Billing::SubscriptionAttributes
  class << self
    def customer_id(subscription)
      customer = subscription.customer
      customer.is_a?(String) ? customer : customer&.id
    end

    def subscription_id(subscription)
      subscription.respond_to?(:id) ? subscription.id : subscription['id']
    end

    def status(subscription)
      value = subscription.respond_to?(:status) ? subscription.status : subscription['status']
      value.to_s
    end

    def items(subscription)
      Array(subscription.items&.data)
    end

    def selected_item(subscription, item_id: nil)
      list = items(subscription)
      return list.first if list.size <= 1
      return list.first if item_id.blank?

      list.find { |item| item.id == item_id } ||
        list.find { |item| item['id'] == item_id }
    end

    def product_id(subscription, item_id: nil)
      item = selected_item(subscription, item_id: item_id)
      return legacy_product_id(subscription) if item.blank?

      price = item.price
      product = price&.product
      return product if product.is_a?(String)
      return product&.id if product.present?

      legacy_product_id(subscription)
    end

    def price_id(subscription, item_id: nil)
      item = selected_item(subscription, item_id: item_id)
      return subscription['plan']['id'] if item.blank? && subscription['plan'].present?

      item&.price&.id || subscription['plan']&.[]('id')
    end

    def quantity(subscription, item_id: nil)
      item = selected_item(subscription, item_id: item_id)
      return item.quantity if item&.quantity.present?
      return subscription['quantity'] if subscription['quantity'].present?

      nil
    end

    def current_period_end(subscription, item_id: nil)
      item = selected_item(subscription, item_id: item_id)
      subscription['current_period_end'] || item.try(:current_period_end)
    end

    def product_name(subscription, item_id: nil)
      item = selected_item(subscription, item_id: item_id)
      product = item&.price&.product
      return product.name if product.respond_to?(:name) && product.name.present?

      nil
    end

    def subscription_item_id(subscription, item_id: nil)
      item = selected_item(subscription, item_id: item_id)
      item&.id
    end

    private

    def legacy_product_id(subscription)
      plan = subscription['plan']
      if plan.present?
        product = plan['product']
        return product if product.is_a?(String)
        return product&.id
      end

      nil
    end
  end
end
