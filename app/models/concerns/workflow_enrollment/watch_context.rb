# frozen_string_literal: true

# Centralised context cleanup so reply_watch and intent_watch are always cleared together.
module WorkflowEnrollment::WatchContext
  extend ActiveSupport::Concern

  def clear_all_watches!
    keys_to_remove = %w[reply_watch intent_watch]
    current = context || {}
    return unless keys_to_remove.any? { |k| current.key?(k) }

    update!(context: current.except(*keys_to_remove))
  end
end
