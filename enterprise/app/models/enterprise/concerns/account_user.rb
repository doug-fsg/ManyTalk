module Enterprise::Concerns::AccountUser
  extend ActiveSupport::Concern

  included do
    belongs_to :custom_role, optional: true
    before_save :clear_custom_role_for_administrator
    validate :custom_role_belongs_to_account
  end

  private

  def clear_custom_role_for_administrator
    self.custom_role_id = nil if administrator?
  end

  def custom_role_belongs_to_account
    return if custom_role.blank? || custom_role.account_id == account_id

    errors.add(:custom_role_id, :invalid)
  end
end
