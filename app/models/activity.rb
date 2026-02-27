# == Schema Information
#
# Table name: activities
#
#  id                          :bigint           not null, primary key
#  account_id                  :bigint           not null
#  user_id                     :bigint           not null
#  assignee_id                 :bigint
#  activity_type               :string           not null
#  title                       :string           not null
#  description                 :text
#  status                      :string           default("pending")
#  scheduled_at                :datetime         not null
#  contact_pipeline_position_id :bigint
#  contact_id                  :bigint
#  conversation_id             :bigint
#  inbox_id                     :bigint
#  message_content             :text
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
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
  validates :status, inclusion: { in: %w[pending completed cancelled] }
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

