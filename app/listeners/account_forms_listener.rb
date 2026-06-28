# frozen_string_literal: true

class AccountFormsListener < BaseListener
  def form_submitted(event)
    account_form = event.data[:account_form]
    contact = event.data[:contact]
    submission = event.data[:submission]
    return if account_form.blank? || contact.blank? || submission.blank?

    Workflows::ProcessFormSubmittedJob.perform_later(
      account_form.account_id,
      contact.id,
      account_form.id,
      submission.id
    )

    dispatch_form_submitted_webhooks(account_form, contact, submission)
  end

  private

  def dispatch_form_submitted_webhooks(account_form, contact, submission)
    account = account_form.account
    payload = {
      event: 'form_submitted',
      form: {
        id: account_form.id,
        name: account_form.name,
        slug: account_form.slug
      },
      contact: contact.webhook_data,
      submission: {
        id: submission.id,
        payload: submission.payload,
        utm: submission.utm,
        created_at: submission.created_at
      }
    }
    account.webhooks.account_type.each do |webhook|
      next unless webhook.subscriptions.include?('form_submitted')

      WebhookJob.perform_later(webhook.url, payload)
    end
  rescue StandardError => e
    Rails.logger.error "[AccountFormsListener] webhook delivery failed: #{e.message}"
  end
end
