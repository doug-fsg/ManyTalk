# == Schema Information
#
# Table name: label_groups
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_label_groups_on_account_id           (account_id)
#  index_label_groups_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class LabelGroup < ApplicationRecord
  include AccountCacheRevalidator

  belongs_to :account
  has_many :labels, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }

  before_create :set_position

  default_scope { order(:position, :name) }

  def update_account_cache
    account.update_cache_key('label_group')
    account.update_cache_key('label')
  end

  private

  def set_position
    return if position.to_i.positive?

    self.position = (account.label_groups.maximum(:position) || 0) + 1
  end
end
