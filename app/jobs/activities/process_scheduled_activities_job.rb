class Activities::ProcessScheduledActivitiesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Buscar atividades que devem ser executadas
    activities = Activity.pending
                         .scheduled_before(Time.current)
                         .includes(:conversation, :user)

    activities.find_each do |activity|
      if activity.scheduled_message?
        Activities::SendScheduledMessageService.new(activity).perform
      end
    end

    Rails.logger.info "Processadas #{activities.count} atividades agendadas"
  end
end

