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

      node = @workflow.find_node(@node_id)
      data = node&.dig('data') || {}
      content, variant_id = resolve_message_content(data, message)

      params = {
        content: Workflows::MessageInterpolator.new(@conversation).interpolate(content),
        private: false,
        content_attributes: {
          workflow_id: @workflow.id,
          workflow_node_id: @node_id,
          ab_variant_id: variant_id
        }.compact
      }
      Messages::MessageBuilder.new(nil, @conversation, params).perform
      track_variant_execution(variant_id) if variant_id.present?
    end

    def resolve_message_content(data, message)
      if data.dig('ab_test', 'enabled') && data['variants'].present?
        variant = Workflows::AbVariantSelector.new(
          contact_id: @conversation.contact_id,
          node_id: @node_id,
          variants: data['variants']
        ).selected_variant
        [variant['message'], variant['id']]
      else
        [message[0] || data.dig('action_params', 0), nil]
      end
    end

    def track_variant_execution(variant_id)
      enrollment = WorkflowEnrollment.enrollments_for_conversation(@conversation).first
      return if enrollment.blank?

      execution = enrollment.workflow_step_executions.find_by(node_id: @node_id)
      return if execution.blank?

      execution.update!(metadata: (execution.metadata || {}).merge('variant_id' => variant_id))
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

    def send_whatsapp_external(params)
      inbox_id = params[0]
      phone_number = params[1]
      raw_message = params[2] || ''
      content = Workflows::MessageInterpolator.new(@conversation).interpolate(raw_message)

      Workflows::ExternalWhatsappNotifier.new(
        account: @account,
        inbox_id: inbox_id,
        phone_number: phone_number,
        message: content
      ).send!
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
