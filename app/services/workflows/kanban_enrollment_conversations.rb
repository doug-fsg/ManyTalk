# frozen_string_literal: true

module Workflows
  # Resolves which conversations a Kanban trigger may enroll on.
  # Existing open chats are unchanged. A conversation is created only when the
  # contact has none and a single WhatsApp-capable inbox can be chosen safely.
  class KanbanEnrollmentConversations
    def initialize(contact, workflow: nil)
      @contact = contact
      @workflow = workflow
    end

    def resolve
      resolve_for(nil)
    end

    def resolve_for(workflow)
      @workflow = workflow if workflow.present?

      open = @contact.conversations.open.order(updated_at: :desc).limit(1)
      return open.to_a if open.exists?

      if workflow && workflow.settings['cancel_on_conversation_resolved'] == false
        latest = @contact.conversations.order(updated_at: :desc).limit(1)
        return latest.to_a if latest.exists?
      end

      return [] if @contact.conversations.exists?

      created = ensure_whatsapp_conversation
      created.present? ? [created] : []
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: @contact.account).capture_exception
      Rails.logger.error do
        "[Workflow][Kanban] Failed to resolve conversation contact=#{@contact.id} error=#{e.message}"
      end
      []
    end

    private

    def ensure_whatsapp_conversation
      contact_inbox = selectable_contact_inbox
      return if contact_inbox.blank?

      Conversation.create!(
        account_id: @contact.account_id,
        inbox_id: contact_inbox.inbox_id,
        contact_id: @contact.id,
        contact_inbox_id: contact_inbox.id,
        additional_attributes: { 'workflow_kanban_bootstrap' => true }
      )
    end

    def selectable_contact_inbox
      inbox = preferred_inbox
      return contact_inbox_for(inbox) if inbox.present?

      existing = existing_whatsapp_contact_inboxes
      return existing.max_by(&:updated_at) if existing.any?

      build_contact_inbox_for_single_whatsapp_inbox
    end

    def preferred_inbox
      return if @workflow.blank?

      inbox_id = KanbanActionInbox.id_from(@workflow)
      return if inbox_id.blank?

      inbox = @contact.account.inboxes.find_by(id: inbox_id)
      return unless inbox&.external_whatsapp_capable?

      inbox
    end

    def contact_inbox_for(inbox)
      existing = @contact.contact_inboxes.find_by(inbox: inbox)
      return existing if existing
      return if @contact.phone_number.blank?

      ContactInboxBuilder.new(contact: @contact, inbox: inbox).perform
    rescue StandardError => e
      Rails.logger.warn do
        "[Workflow][Kanban] Could not build contact inbox for configured inbox contact=#{@contact.id} inbox=#{inbox.id} error=#{e.message}"
      end
      nil
    end

    def existing_whatsapp_contact_inboxes
      @contact.contact_inboxes.includes(:inbox).select { |ci| ci.inbox&.external_whatsapp_capable? }
    end

    def build_contact_inbox_for_single_whatsapp_inbox
      return if @contact.phone_number.blank?

      inboxes = whatsapp_inboxes_for_account
      return unless inboxes.one?

      ContactInboxBuilder.new(contact: @contact, inbox: inboxes.first).perform
    rescue StandardError => e
      Rails.logger.warn do
        "[Workflow][Kanban] Could not build contact inbox contact=#{@contact.id} error=#{e.message}"
      end
      nil
    end

    def whatsapp_inboxes_for_account
      @contact.account.inboxes.select(&:external_whatsapp_capable?)
    end
  end
end
