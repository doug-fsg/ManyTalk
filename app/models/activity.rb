# == Schema Information
#
# Table name: activities
#
#  id                           :bigint           not null, primary key
#  activity_type                :string           not null
#  description                  :text
#  message_content              :text
#  scheduled_at                 :datetime         not null
#  status                       :string           default("pending")
#  title                        :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  assignee_id                  :bigint
#  contact_id                   :bigint
#  contact_pipeline_position_id :bigint
#  conversation_id              :bigint
#  inbox_id                     :bigint
#  metadata                     :jsonb            not null
#  user_id                      :bigint           not null
#
# Indexes
#
#  index_activities_on_account_id                    (account_id)
#  index_activities_on_account_id_and_assignee_id    (account_id,assignee_id)
#  index_activities_on_account_id_and_scheduled_at   (account_id,scheduled_at)
#  index_activities_on_account_id_and_status         (account_id,status)
#  index_activities_on_assignee_id                   (assignee_id)
#  index_activities_on_contact_id                    (contact_id)
#  index_activities_on_contact_pipeline_position_id  (contact_pipeline_position_id)
#  index_activities_on_conversation_id               (conversation_id)
#  index_activities_on_inbox_id                      (inbox_id)
#  index_activities_on_user_id                       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (contact_pipeline_position_id => contact_pipeline_positions.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (user_id => users.id)
#

class Activity < ApplicationRecord
  audited

  belongs_to :account
  belongs_to :user
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :contact_pipeline_position, optional: true
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true

  validates :activity_type, inclusion: { in: %w[task scheduled_message] }
  validates :status, inclusion: { in: %w[pending completed cancelled failed] }
  validates :title, presence: true
  validates :scheduled_at, presence: true
  validates :message_content, presence: true, if: -> { scheduled_message? }
  validates :inbox_id, presence: true, if: -> { scheduled_message? }

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_assignee, ->(user_id) { where(assignee_id: user_id) }
  scope :scheduled_before, ->(time) { where('scheduled_at <= ?', time) }
  scope :ordered, -> { order(scheduled_at: :asc) }

  def complete!
    update!(status: 'completed')
  end

  def cancel!
    update!(status: 'cancelled')
  end

  def fail!(reason:, error: nil)
    metadata = (self.metadata || {}).merge(
      'failure_reason' => reason,
      'last_error' => error,
      'failed_at' => Time.current.iso8601
    )
    update!(status: 'failed', metadata: metadata)
  end

  def task?
    activity_type == 'task'
  end

  def scheduled_message?
    activity_type == 'scheduled_message'
  end

  def overdue?
    pending? && scheduled_at < Time.current
  end

  def pending?
    status == 'pending'
  end
end

