# frozen_string_literal: true

module AiAttendant
  class WorkingHoursPolicy
    class << self
      def allow?(inbox:, schedule_mode:, at: Time.zone.now)
        return true if schedule_mode.to_s == 'always'
        return true unless inbox.working_hours_enabled?

        open = inbox_open?(inbox, at)

        case schedule_mode.to_s
        when 'within_inbox_hours'
          open
        when 'outside_inbox_hours'
          !open
        else
          false
        end
      end

      private

      def inbox_open?(inbox, at)
        timezone = inbox.timezone.presence || 'America/Sao_Paulo'
        local = at.in_time_zone(timezone)
        working_hour = inbox.working_hours.find_by(day_of_week: local.wday)
        return false if working_hour.blank? || working_hour.closed_all_day?
        return true if working_hour.open_all_day?

        open_at = local.change(hour: working_hour.open_hour, min: working_hour.open_minutes)
        close_at = local.change(hour: working_hour.close_hour, min: working_hour.close_minutes)
        local.between?(open_at, close_at)
      end
    end
  end
end
