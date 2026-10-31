# frozen_string_literal: true

class AiAttendant::ProcessMessageJob < ApplicationJob
  queue_as :high

  HISTORY_LIMIT = 10
  LLM_FALLBACK_TEXT = 'Não consegui processar; vou chamar um atendente'

  def perform(account_id, inbox_id, conversation_id, message_ids = [])
    account = Account.find_by(id: account_id)
    inbox = Inbox.find_by(id: inbox_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if account.blank? || inbox.blank? || conversation.blank?

    combined_content = take_combined_content(
      account_id: account.id,
      inbox_id: inbox.id,
      conversation_id: conversation.id,
      message_ids: message_ids
    )

    config = AiAttendantConfig.for_inbox(inbox.id).find_by(account_id: account.id)
    return persist_run(account: account, conversation: conversation, inbox: inbox, status: 'skipped', skip_reason: 'config_missing') if config.blank?

    unless AiAttendant::WorkingHoursPolicy.allow?(inbox: inbox, schedule_mode: config.schedule_mode)
      return persist_run(
        account: account,
        conversation: conversation,
        inbox: inbox,
        status: 'skipped',
        skip_reason: 'working_hours'
      )
    end

    unless PlatformAi::QuotaGuard.allow?(account: account)
      return persist_run(
        account: account,
        conversation: conversation,
        inbox: inbox,
        status: 'skipped',
        skip_reason: 'no_credits'
      )
    end

    if combined_content.blank?
      return persist_run(
        account: account,
        conversation: conversation,
        inbox: inbox,
        status: 'skipped',
        skip_reason: 'empty_content'
      )
    end

    system = AiAttendant::PromptBuilder.build_system(config: config, conversation: conversation)
    user = AiAttendant::PromptBuilder.build_user(config: config, combined_text: combined_content, at: Time.current)
    history = conversation_history(conversation, message_ids)

    result = AiAttendant::ChatService.new(
      conversation: conversation,
      config: config,
      system: system,
      user: user,
      history: history
    ).perform

    handle_chat_result(account: account, conversation: conversation, inbox: inbox, config: config, result: result)
  end

  private

  def take_combined_content(account_id:, inbox_id:, conversation_id:, message_ids:)
    buffer = AiAttendant::MessageBuffer.new(
      account_id: account_id,
      inbox_id: inbox_id,
      conversation_id: conversation_id
    )
    content = buffer.combined_content.presence || content_from_message_ids(message_ids)
    buffer.clear!
    content.to_s
  end

  def content_from_message_ids(message_ids)
    Message.where(id: Array(message_ids)).order(:created_at).filter_map { |message| message.content.presence }.join("\n")
  end

  def conversation_history(conversation, message_ids)
    conversation.messages
                .where(private: false, message_type: %i[incoming outgoing])
                .where.not(id: Array(message_ids))
                .order(created_at: :desc)
                .limit(HISTORY_LIMIT)
                .to_a
                .reverse
                .map { |message| { role: message.incoming? ? 'user' : 'assistant', content: message.content.to_s } }
  end

  def handle_chat_result(account:, conversation:, inbox:, config:, result:)
    payload = (result || {}).with_indifferent_access
    text = payload[:text].presence
    handed_off = ActiveModel::Type::Boolean.new.cast(payload[:handoff])
    tokens = payload[:tokens].to_i
    metadata = { 'credits_charged' => payload[:credits_charged] }.compact

    if text.present?
      AiAttendant::ResponseSender.new(
        conversation: conversation,
        sender: config.sender_user,
        text: text,
        config: config
      ).perform
      return persist_run(
        account: account,
        conversation: conversation,
        inbox: inbox,
        status: handed_off ? 'handoff' : 'success',
        tokens: tokens,
        metadata: metadata
      )
    end

    if handed_off
      return persist_run(
        account: account,
        conversation: conversation,
        inbox: inbox,
        status: 'handoff',
        tokens: tokens,
        metadata: metadata
      )
    end

    AiAttendant::ResponseSender.new(
      conversation: conversation,
      sender: config.sender_user,
      text: LLM_FALLBACK_TEXT,
      config: config
    ).perform
    AiAttendant::HandoffService.new(conversation: conversation, summary: LLM_FALLBACK_TEXT, config: config).perform
    persist_run(
      account: account,
      conversation: conversation,
      inbox: inbox,
      status: 'error',
      tokens: tokens,
      error_message: LLM_FALLBACK_TEXT,
      metadata: metadata
    )
  end

  def persist_run(account:, conversation:, inbox:, status:, skip_reason: nil, tokens: 0, error_message: nil, metadata: {})
    AiAttendantRun.create!(
      account: account,
      conversation: conversation,
      inbox: inbox,
      status: status,
      skip_reason: skip_reason,
      tokens: tokens,
      error_message: error_message,
      metadata: metadata
    )
  end
end
