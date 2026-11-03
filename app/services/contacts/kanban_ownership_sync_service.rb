# frozen_string_literal: true

module Contacts
  # Sincroniza o responsável do card com o atendente da conversa-alvo
  # apenas em pipelines com ownership_mode "linked".
  class KanbanOwnershipSyncService
    ACTIVE_STATUSES = %w[open pending].freeze

    def self.sync_pipeline_assignee_to_conversation(position)
      new(position).sync_pipeline_assignee_to_conversation
    end

    def self.sync_owner_from_primary_conversation(position)
      new(position).sync_owner_from_primary_conversation
    end

    def self.sync_conversation_assignee_to_pipelines(conversation)
      return if Current.skip_kanban_ownership_sync
      return if conversation.blank? || conversation.contact.blank?

      with_sync_suppressed do
        conversation.contact.contact_pipeline_positions.includes(:pipeline).find_each do |position|
          next unless position.pipeline&.kanban_ownership_linked?
          next if position.assignee_id == conversation.assignee_id

          position.update!(assignee_id: conversation.assignee_id)
        end
      end
    end

    def self.with_sync_suppressed
      Current.skip_kanban_ownership_sync = true
      yield
    ensure
      Current.skip_kanban_ownership_sync = nil
    end

    def initialize(position)
      @position = position
    end

    def sync_owner_from_primary_conversation
      return if Current.skip_kanban_ownership_sync
      return unless @position&.pipeline&.kanban_ownership_linked?

      conversation = explicitly_selected_conversation || resolve_primary_conversation
      return if conversation.blank?
      return if @position.assignee_id == conversation.assignee_id

      self.class.with_sync_suppressed do
        @position.update!(assignee_id: conversation.assignee_id)
      end
    end

    def sync_pipeline_assignee_to_conversation
      return if Current.skip_kanban_ownership_sync
      return unless @position&.pipeline&.kanban_ownership_linked?

      conversation = resolve_primary_conversation
      return if conversation.blank?
      return if conversation.assignee_id == @position.assignee_id

      self.class.with_sync_suppressed do
        conversation.update!(assignee_id: @position.assignee_id)
      end
    end

    def explicitly_selected_conversation
      contact = @position.contact
      return if contact.blank?

      stored_id = @position.metadata.is_a?(Hash) ? @position.metadata['primary_conversation_id'] : nil
      return if stored_id.blank?

      contact.conversations.find_by(display_id: stored_id.to_i) ||
        contact.conversations.find_by(id: stored_id.to_i)
    end

    def resolve_primary_conversation
      contact = @position.contact
      return if contact.blank?

      candidates = contact.conversations.where(status: ACTIVE_STATUSES)
      stored_id = @position.metadata.is_a?(Hash) ? @position.metadata['primary_conversation_id'] : nil

      if stored_id.present?
        stored = candidates.find_by(display_id: stored_id.to_i) || candidates.find_by(id: stored_id.to_i)
        return stored if stored.present?
      end

      candidates.order(last_activity_at: :desc).first
    end
  end
end
