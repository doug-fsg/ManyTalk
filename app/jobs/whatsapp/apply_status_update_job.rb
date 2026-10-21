# frozen_string_literal: true

# Applies WhatsApp Cloud status webhooks (sent/delivered/read/failed) with retry when
# the outbound message source_id is not yet persisted (race with SendReplyJob).
class Whatsapp::ApplyStatusUpdateJob < ApplicationJob
  queue_as :low

  retry_on ActiveRecord::RecordNotFound, wait: 3.seconds, attempts: 5

  def perform(source_id:, status_payload:, inbox_id: nil)
    return if source_id.blank?

    message = find_message(source_id, inbox_id)
    raise ActiveRecord::RecordNotFound, "WhatsApp message source_id=#{source_id} not found" if message.blank?

    apply_status(message, status_payload.with_indifferent_access)
  end

  private

  def find_message(source_id, inbox_id)
    scope = Message.where(source_id: source_id)
    scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
    scope.order(id: :desc).first
  end

  def apply_status(message, status)
    if status[:status] == 'deleted'
      message.assign_attributes(
        content: I18n.t('conversations.messages.deleted'),
        content_attributes: message.content_attributes.merge(deleted: true)
      )
    else
      message.status = status[:status]
    end

    if status[:status] == 'failed' && status[:errors].present?
      message.external_error = Whatsapp::ErrorHumanizer.humanize_from_status_error(status[:errors]&.first)
    end

    message.save!
  rescue ArgumentError => e
    Rails.logger.error "Error while processing whatsapp status update #{e.message}"
  end
end
