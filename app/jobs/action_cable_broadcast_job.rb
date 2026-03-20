class ActionCableBroadcastJob < ApplicationJob
  queue_as :critical

  def perform(members, event_name, data)
    payload = { event: event_name, data: data }
    members.each do |member|
      begin
        ActionCable.server.broadcast(member, payload)
      rescue Errno::EPIPE, IOError, EOFError => e
        Rails.logger.warn("ActionCable broadcast failed for #{member}: #{e.class} - #{e.message}")
      end
    end
  end
end
