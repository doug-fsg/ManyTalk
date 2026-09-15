class Enterprise::Billing::Lock
  LOCKED_STATUSES = %w[unpaid canceled incomplete_expired].freeze
  WARNING_STATUSES = %w[past_due incomplete].freeze

  def self.locked?(account)
    LOCKED_STATUSES.include?(subscription_status(account))
  end

  def self.warning?(account)
    WARNING_STATUSES.include?(subscription_status(account))
  end

  def self.subscription_status(account)
    account&.custom_attributes&.[]('subscription_status').to_s
  end
end
