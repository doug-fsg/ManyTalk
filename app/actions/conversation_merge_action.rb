# frozen_string_literal: true

class ConversationMergeAction
  include Events::Types

  pattr_initialize [:account!, :base_conversation!, :mergee_conversation!]

  def perform
    return @base_conversation if base_conversation.id == mergee_conversation.id

    ActiveRecord::Base.transaction do
      lock_conversations
      validate_conversations!
      cancel_mergee_workflow_enrollments
      merge_messages
      merge_mentions
      merge_participants
      merge_csat_survey_response
      merge_form_submissions
      merge_activities
      merge_reporting_events
      merge_enterprise_sla_records
      merge_labels
      merge_conversation_attributes
      refresh_base_conversation_timestamps
      create_merge_activity_message
      destroy_mergee_conversation
    end

    dispatch_merged_event
    @base_conversation.reload
  end

  private

  def lock_conversations
    @base_conversation = base_conversation.lock!
    @mergee_conversation = mergee_conversation.lock!
  end

  def validate_conversations!
    unless belongs_to_account?(base_conversation) && belongs_to_account?(mergee_conversation)
      raise_invalid_merge!(I18n.t('conversations.merge.errors.account_mismatch'))
    end

    if base_conversation.inbox_id != mergee_conversation.inbox_id
      raise_invalid_merge!(I18n.t('conversations.merge.errors.inbox_mismatch'))
    end

    return if base_conversation.contact_id == mergee_conversation.contact_id

    raise_invalid_merge!(I18n.t('conversations.merge.errors.contact_mismatch'))
  end

  def belongs_to_account?(conversation)
    account.id == conversation.account_id
  end

  def raise_invalid_merge!(message)
    raise CustomExceptions::ConversationMerge::InvalidMerge.new(message: message)
  end

  def cancel_mergee_workflow_enrollments
    mergee_conversation.workflow_enrollments.where(status: %w[active waiting paused]).find_each do |enrollment|
      enrollment.cancel!('conversation_merged')
    end
  end

  def merge_messages
    Message.where(conversation_id: mergee_conversation.id).update_all(
      conversation_id: base_conversation.id,
      updated_at: Time.current
    )
  end

  def merge_mentions
    existing_user_ids = base_conversation.mentions.pluck(:user_id)

    mergee_conversation.mentions.find_each do |mention|
      if existing_user_ids.include?(mention.user_id)
        mention.destroy!
      else
        mention.update!(conversation_id: base_conversation.id)
        existing_user_ids << mention.user_id
      end
    end
  end

  def merge_participants
    existing_user_ids = base_conversation.conversation_participants.pluck(:user_id)

    mergee_conversation.conversation_participants.find_each do |participant|
      if existing_user_ids.include?(participant.user_id)
        participant.destroy!
      else
        participant.update!(conversation_id: base_conversation.id)
        existing_user_ids << participant.user_id
      end
    end
  end

  def merge_csat_survey_response
    mergee_csat = mergee_conversation.csat_survey_response
    return unless mergee_csat
    return if base_conversation.csat_survey_response.present?

    mergee_csat.update!(conversation_id: base_conversation.id)
  end

  def merge_form_submissions
    FormSubmission.where(conversation_id: mergee_conversation.id).update_all(
      conversation_id: base_conversation.id,
      updated_at: Time.current
    )
  end

  def merge_activities
    Activity.where(conversation_id: mergee_conversation.id).update_all(
      conversation_id: base_conversation.id,
      updated_at: Time.current
    )
  end

  def merge_reporting_events
    ReportingEvent.where(conversation_id: mergee_conversation.id).update_all(
      conversation_id: base_conversation.id,
      updated_at: Time.current
    )
  end

  def merge_enterprise_sla_records
    return unless ChatwootApp.enterprise?

    merge_applied_sla
    merge_sla_events
  end

  def merge_applied_sla
    mergee_sla = AppliedSla.find_by(conversation_id: mergee_conversation.id)
    return unless mergee_sla

    if AppliedSla.exists?(conversation_id: base_conversation.id)
      mergee_sla.destroy!
    else
      mergee_sla.update!(conversation_id: base_conversation.id)
    end
  end

  def merge_sla_events
    return unless defined?(SlaEvent)

    SlaEvent.where(conversation_id: mergee_conversation.id).update_all(
      conversation_id: base_conversation.id,
      updated_at: Time.current
    )
  end

  def merge_labels
    merged_labels = (
      base_conversation.label_list + mergee_conversation.label_list
    ).map(&:strip).reject(&:blank?).uniq

    base_conversation.update_labels(merged_labels)
  end

  def merge_conversation_attributes
    merged_custom_attributes = mergee_conversation.custom_attributes.deep_merge(base_conversation.custom_attributes)
    merged_additional_attributes = mergee_conversation.additional_attributes.deep_merge(base_conversation.additional_attributes)

    base_conversation.update!(
      custom_attributes: merged_custom_attributes,
      additional_attributes: merged_additional_attributes
    )
  end

  def refresh_base_conversation_timestamps
    attrs = {
      last_activity_at: [base_conversation.last_activity_at, mergee_conversation.last_activity_at].compact.max
    }

    base_first_reply = base_conversation.first_reply_created_at
    mergee_first_reply = mergee_conversation.first_reply_created_at
    if base_first_reply.present? || mergee_first_reply.present?
      attrs[:first_reply_created_at] = [base_first_reply, mergee_first_reply].compact.min
    end

    if base_conversation.waiting_since.blank? && mergee_conversation.waiting_since.present?
      attrs[:waiting_since] = mergee_conversation.waiting_since
    end

    base_conversation.update!(attrs)
  end

  def create_merge_activity_message
    user_name = Current.user&.name || 'System'
    content = I18n.t(
      'conversations.activity.merged',
      mergee_display_id: mergee_conversation.display_id,
      user_name: user_name
    )

    ::Conversations::ActivityMessageJob.perform_later(
      base_conversation,
      account_id: account.id,
      inbox_id: base_conversation.inbox_id,
      message_type: :activity,
      content: content
    )
  end

  def destroy_mergee_conversation
    mergee_display_id = mergee_conversation.display_id
    mergee_conversation.workflow_enrollments.find_each(&:destroy!)
    mergee_conversation.destroy!
    @merged_display_id = mergee_display_id
  end

  def dispatch_merged_event
    tokens = base_conversation.inbox.members.map(&:pubsub_token) +
             [base_conversation.contact_inbox.pubsub_token]

    Rails.configuration.dispatcher.dispatch(
      CONVERSATION_MERGED,
      Time.zone.now,
      conversation: @base_conversation,
      mergee_display_id: @merged_display_id,
      tokens: tokens.compact.uniq
    )
  end
end
