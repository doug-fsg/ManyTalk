# frozen_string_literal: true

class KanbanOwnershipListener < BaseListener
  def conversation_updated(event)
    return if Current.skip_kanban_ownership_sync

    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?
    return unless assignee_changed?(event)

    Contacts::KanbanOwnershipSyncService.sync_conversation_assignee_to_pipelines(conversation)
  end

  private

  def assignee_changed?(event)
    changes = event.data[:changed_attributes]
    return false unless changes.respond_to?(:[])

    assignee_change = changes['assignee_id'] || changes[:assignee_id]
    assignee_change.is_a?(Array)
  end
end
