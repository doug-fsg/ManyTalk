# frozen_string_literal: true

module Workflows
  class BusinessHoursScheduler
    include ReportingEventHelper

    def initialize(inbox)
      @inbox = inbox
    end

    def adjust(time)
      return time unless respect_business_hours?
      return time unless @inbox.working_hours_enabled?

      adjusted = next_allowed_time(time)
      adjusted || time
    end

    def rescheduled?(original, adjusted)
      original.present? && adjusted.present? && adjusted > original
    end

    private

    def respect_business_hours?
      true
    end

    def next_allowed_time(time)
      timezone = @inbox.timezone
      local = time.in_time_zone(timezone)

      14.times do
        return local if within_working_hours?(local)

        local = next_window_start(local)
      end

      time
    end

    def within_working_hours?(local)
      working_hour = @inbox.working_hours.find_by(day_of_week: local.wday)
      return false if working_hour.blank? || working_hour.closed_all_day?

      open_at = local.change(hour: working_hour.open_hour, min: working_hour.open_minutes)
      close_at = local.change(hour: working_hour.close_hour, min: working_hour.close_minutes)
      local >= open_at && local < close_at
    end

    def next_window_start(local)
      timezone = @inbox.timezone
      candidate = local

      8.times do
        working_hour = @inbox.working_hours.find_by(day_of_week: candidate.wday)
        if working_hour.present? && !working_hour.closed_all_day?
          open_at = candidate.in_time_zone(timezone).change(
            hour: working_hour.open_hour,
            min: working_hour.open_minutes
          )
          return open_at if open_at > local
        end
        candidate = candidate.in_time_zone(timezone).beginning_of_day + 1.day
      end

      local + 1.hour
    end
  end
end
