class EventDispatcherJob < ApplicationJob
  queue_as :critical

  def perform(event_name, timestamp, data)
    hydrated = Events::PayloadSerializer.load(data)

    if Events::PayloadSerializer.missing_primary_record?(event_name, hydrated)
      Rails.logger.warn("[EventDispatcherJob] Skipping #{event_name}: referenced record was deleted")
      return
    end

    Rails.configuration.dispatcher.async_dispatcher.publish_event(event_name, timestamp, hydrated)
  end
end
