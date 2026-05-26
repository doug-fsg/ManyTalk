# frozen_string_literal: true

module Workflows
  class ActionService < ::ActionService
    def initialize(workflow, account, conversation, node_id:)
      super(conversation)
      @workflow = workflow
      @account = account
      @node_id = node_id
      Current.executed_by = workflow
    end

    def perform_action(action_name, action_params)
      @conversation.reload
      send(action_name, action_params)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: @account).capture_exception
    ensure
      Current.reset
    end

    private

    def send_message(message)
      return if conversation_a_tweet?

      params = {
        content: message[0],
        private: false,
        content_attributes: { workflow_id: @workflow.id, workflow_node_id: @node_id }
      }
      Messages::MessageBuilder.new(nil, @conversation, params).perform
    end

    def add_private_note(message)
      return if conversation_a_tweet?

      params = {
        content: message[0],
        private: true,
        content_attributes: { workflow_id: @workflow.id, workflow_node_id: @node_id }
      }
      Messages::MessageBuilder.new(nil, @conversation, params).perform
    end

    def send_webhook_event(webhook_url)
      payload = @conversation.webhook_data.merge(event: "workflow_event.#{@workflow.id}")
      WebhookJob.perform_later(webhook_url[0], payload)
    end

    def send_attachment(blob_ids)
      return if conversation_a_tweet?

      blobs = ActiveStorage::Blob.where(id: blob_ids)
      return if blobs.blank?

      params = { content: nil, private: false, attachments: blobs }
      Messages::MessageBuilder.new(nil, @conversation, params).perform
    end

    def send_email_to_team(params)
      teams = Team.where(id: params[0][:team_ids])
      teams.each do |team|
        TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      end
    end

    def change_kanban_stage(stage_params)
      pipeline_id = stage_params[0]
      selected_stage = stage_params[1]
      return unless pipeline_id.present? && selected_stage.present?

      contact = @conversation.contact
      return unless contact.present?

      kanban_attribute = @account.custom_attribute_definitions.find_by(id: pipeline_id, is_kanban: true)
      return unless kanban_attribute.present?

      position = ContactPipelinePosition.update_stage(
        contact,
        pipeline_id,
        selected_stage,
        entered_at: Time.current
      )
      return unless position.present?

      content = I18n.t(
        'conversations.activity.kanban.moved',
        user_name: 'Workflow System',
        stage_name: selected_stage
      )
      ::Conversations::ActivityMessageJob.perform_later(
        @conversation,
        {
          account_id: @conversation.account_id,
          inbox_id: @conversation.inbox_id,
          message_type: :activity,
          content: content
        }
      )
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: @account).capture_exception
    end
  end
end
