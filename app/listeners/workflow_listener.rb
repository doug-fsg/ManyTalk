# frozen_string_literal: true

class WorkflowListener < BaseListener
  def conversation_updated(event)
    dispatch_conversation(event, 'conversation_updated')
    handle_label_changes(event)
  end

  def conversation_created(event)
    dispatch_conversation(event, 'conversation_created')
  end

  def conversation_opened(event)
    dispatch_conversation(event, 'conversation_opened')
  end

  def conversation_resolved(event)
    conversation = event.data[:conversation]
    Workflows::ProcessEventJob.perform_later(
      'conversation_resolved',
      conversation.account_id,
      conversation.id,
      nil,
      event.data[:changed_attributes]
    )
    WorkflowEnrollment.cancel_for_conversation!(conversation, reason: 'conversation_resolved')
  end

  def message_created(event)
    message = event.data[:message]
    return if ignore_message_created_event?(event)

    conversation = message.conversation
    Workflows::ProcessEventJob.perform_later(
      'message_created',
      message.account_id,
      conversation.id,
      message.id,
      event.data[:changed_attributes]
    )

    WorkflowEnrollment.handle_reply!(conversation, message)
    WorkflowEnrollment.cancel_for_agent_reply!(conversation) if message.outgoing?
  end

  private

  def dispatch_conversation(event, event_name)
    return if performed_by_workflow?(event)

    conversation = event.data[:conversation]
    Workflows::ProcessEventJob.perform_later(
      event_name,
      conversation.account_id,
      conversation.id,
      nil,
      event.data[:changed_attributes]
    )
  end

  def handle_label_changes(event)
    changed = event.data[:changed_attributes] || {}
    return unless changed.key?('labels')

    conversation = event.data[:conversation]
    current_labels = changed.dig('labels', 1) || conversation.label_list
    WorkflowEnrollment.cancel_for_labels!(conversation, current_labels)
  end

  def performed_by_workflow?(event)
    event.data[:performed_by].present? && event.data[:performed_by].is_a?(Workflow)
  end

  def ignore_message_created_event?(event)
    message = event.data[:message]
    performed_by_workflow?(event) || message.activity? || workflow_message?(message) || external_echo_message?(message)
  end

  def external_echo_message?(message)
    message.content_attributes&.dig('external_echo') == true
  end

  def workflow_message?(message)
    attrs = message.content_attributes || {}
    attrs['workflow_id'].present?
  end
end
