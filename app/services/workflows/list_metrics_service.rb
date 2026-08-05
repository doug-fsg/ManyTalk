# frozen_string_literal: true

module Workflows
  class ListMetricsService
    METRICS_PERIOD = 30.days

    pattr_initialize [:account!, :user!, workflow_ids: []]

    def build
      ids = Array(workflow_ids).map(&:to_i).uniq
      return {} if ids.empty?

      ids.index_with { default_metrics }.tap do |result|
        active_counts.each { |workflow_id, count| result[workflow_id][:active_count] = count }
        reply_rates.each { |workflow_id, rate| result[workflow_id][:reply_rate_30d] = rate }
        completion_rates.each { |workflow_id, rate| result[workflow_id][:completion_rate_30d] = rate }
      end
    end

    private

    def default_metrics
      { active_count: 0, reply_rate_30d: nil, completion_rate_30d: nil }
    end

    def active_counts
      scope = account.workflow_enrollments.in_progress.where(workflow_id: workflow_ids)
      scope = scope.joins(:conversation).where(conversations: { inbox_id: assigned_inbox_ids }) unless administrator?
      scope.group(:workflow_id).count
    end

    def reply_rates
      historical_enrollments.transform_values do |enrollments|
        total = enrollments.size
        next nil if total.zero?

        replied = enrollments.count { |enrollment| EnrollmentMetrics.contact_replied_during?(enrollment) }
        (replied.to_f / total * 100).round(1)
      end
    end

    def completion_rates
      historical_enrollments.transform_values do |enrollments|
        total = enrollments.size
        next nil if total.zero?

        completed = enrollments.count { |enrollment| enrollment.status == 'completed' }
        (completed.to_f / total * 100).round(1)
      end
    end

    def historical_enrollments
      scope = account.workflow_enrollments.includes(:conversation)
                     .where(workflow_id: workflow_ids, created_at: METRICS_PERIOD.ago..)
      scope = scope.joins(:conversation).where(conversations: { inbox_id: assigned_inbox_ids }) unless administrator?

      scope.group_by(&:workflow_id)
    end

    def assigned_inbox_ids
      @assigned_inbox_ids ||= if administrator?
                                account.inboxes.pluck(:id)
                              else
                                user.inboxes.where(account_id: account.id).pluck(:id)
                              end
    end

    def administrator?
      account.account_users.find_by(user_id: user.id)&.administrator?
    end
  end
end
