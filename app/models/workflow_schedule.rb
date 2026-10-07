# frozen_string_literal: true

# == Schema Information
#
# Table name: workflow_schedules
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(FALSE), not null
#  hour             :integer          not null
#  last_enqueued_at :datetime
#  last_finished_at :datetime
#  last_run_stats   :jsonb            not null
#  last_run_status  :string
#  minute           :integer          default(0), not null
#  name             :string           not null
#  next_run_at      :datetime
#  recurring        :boolean          default(TRUE), not null
#  run_token        :integer          default(0), not null
#  time_zone        :string           default("America/Sao_Paulo"), not null
#  weekday          :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  created_by_id    :bigint
#  pipeline_id      :bigint           not null
#  stage_id         :string           not null
#  workflow_id      :bigint           not null
#
# Indexes
#
#  idx_workflow_schedules_account_active    (account_id,active)
#  idx_workflow_schedules_due               (active,next_run_at) WHERE (active = true)
#  index_workflow_schedules_on_account_id   (account_id)
#  index_workflow_schedules_on_pipeline_id  (pipeline_id)
#  index_workflow_schedules_on_workflow_id  (workflow_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (pipeline_id => custom_attribute_definitions.id)
#  fk_rails_...  (workflow_id => workflows.id)
#
class WorkflowSchedule < ApplicationRecord
  MAX_PER_ACCOUNT = 20
  ALLOWED_TIME_ZONES = %w[
    America/Sao_Paulo
    America/Manaus
    America/Rio_Branco
    America/Noronha
    UTC
  ].freeze

  belongs_to :account
  belongs_to :workflow
  belongs_to :pipeline, class_name: 'CustomAttributeDefinition'
  belongs_to :created_by, class_name: 'User', optional: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :stage_id, presence: true
  validates :weekday, inclusion: { in: 0..6 }, if: :recurring?
  validates :next_run_at, presence: true, unless: :recurring?
  validates :hour, inclusion: { in: 0..23 }
  validates :minute, inclusion: { in: 0..59 }
  validates :time_zone, inclusion: { in: ALLOWED_TIME_ZONES }
  validate :workflow_belongs_to_account
  validate :pipeline_is_kanban_on_account
  validate :stage_exists_on_pipeline
  validate :workflow_active_when_schedule_active
  validate :account_schedule_limit, on: :create

  before_validation :clear_weekday_unless_recurring
  before_validation :assign_next_run_at, if: :should_recalculate_next_run_at?
  before_save :refresh_next_run_if_activating

  scope :active, -> { where(active: true) }

  def compute_next_run_at(from: Time.current)
    return next_run_at unless recurring?

    self.class.next_occurrence(
      weekday: weekday,
      hour: hour,
      minute: minute,
      time_zone: time_zone,
      from: from
    )
  end

  def self.audience_counts_for(schedules)
    return {} if schedules.blank?

    account_id = schedules.first.account_id
    ContactPipelinePosition
      .joins(:contact)
      .where(
        contacts: { account_id: account_id },
        pipeline_id: schedules.map(&:pipeline_id).uniq,
        stage_id: schedules.map(&:stage_id).uniq
      )
      .group(:pipeline_id, :stage_id)
      .count
  end

  def self.next_occurrence(weekday:, hour:, minute:, time_zone:, from: Time.current)
    zone = Time.find_zone(time_zone) || Time.find_zone('UTC')
    local = from.in_time_zone(zone)
    candidate = local.change(hour: hour, min: minute, sec: 0)
    days_ahead = (weekday.to_i - candidate.wday) % 7
    candidate += days_ahead.days
    candidate += 7.days if candidate <= local
    candidate
  end

  def self.claim_due!(now: Time.current, limit: 10)
    transaction do
      records = active
                .where(next_run_at: ..now)
                .order(:next_run_at)
                .limit(limit)
                .lock('FOR UPDATE SKIP LOCKED')
                .to_a

      records.each { |schedule| schedule.claim!(now) }
      records
    end
  end

  def claim!(now = Time.current)
    attrs = {
      run_token: run_token + 1,
      last_enqueued_at: now,
      last_run_status: 'running',
      last_run_stats: { 'enrolled' => 0, 'skipped' => 0, 'failed' => 0 }
    }
    if recurring?
      attrs[:next_run_at] = compute_next_run_at(from: now)
    else
      attrs[:active] = false
    end
    update!(attrs)
  end

  def finish_run!(status:)
    update!(
      last_run_status: status,
      last_finished_at: Time.current
    )
  end

  def increment_run_stat!(key, by = 1)
    return if by.zero?

    with_lock do
      stats = (last_run_stats || {}).dup
      stats[key.to_s] = stats[key.to_s].to_i + by
      update!(last_run_stats: stats)
    end
  end

  def audience_scope
    ContactPipelinePosition
      .joins(:contact)
      .where(contacts: { account_id: account_id }, pipeline_id: pipeline_id, stage_id: stage_id)
  end

  def audience_count
    audience_scope.count
  end

  private

  def should_recalculate_next_run_at?
    return false unless recurring?
    return true if next_run_at.blank?
    return false if new_record?

    weekday_changed? || hour_changed? || minute_changed? || time_zone_changed?
  end

  def clear_weekday_unless_recurring
    self.weekday = nil unless recurring?
  end

  def assign_next_run_at
    self.next_run_at = compute_next_run_at
  end

  def refresh_next_run_if_activating
    return if new_record?
    return unless recurring?
    return unless active? && will_save_change_to_active?

    self.next_run_at = compute_next_run_at
  end

  def workflow_belongs_to_account
    return if workflow.blank? || account_id.blank?
    return if workflow.account_id == account_id

    errors.add(:workflow_id, :invalid)
  end

  def pipeline_is_kanban_on_account
    return if pipeline.blank? || account_id.blank?

    unless pipeline.account_id == account_id && pipeline.is_kanban?
      errors.add(:pipeline_id, :invalid)
    end
  end

  def stage_exists_on_pipeline
    return if pipeline.blank? || stage_id.blank?

    stage_labels = CustomAttributes::ValuesNormalizer.labels(pipeline.attribute_values)
    return if stage_labels.include?(stage_id.to_s)

    errors.add(:stage_id, :invalid)
  end

  def workflow_active_when_schedule_active
    return unless active?
    return if workflow&.active?

    errors.add(:workflow_id, :inactive)
  end

  def account_schedule_limit
    return if account_id.blank?
    return if account.workflow_schedules.count < MAX_PER_ACCOUNT

    errors.add(:account_id, :limit_reached)
  end
end
