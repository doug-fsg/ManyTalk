class Enterprise::Billing::CustomAttributes
  def self.merge!(account, attrs)
    current = (account.custom_attributes || {}).with_indifferent_access
    account.update!(custom_attributes: current.merge(attrs.to_h.with_indifferent_access))
  end
end
