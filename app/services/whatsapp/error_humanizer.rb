# frozen_string_literal: true

module Whatsapp::ErrorHumanizer
  module_function

  def humanize(code:, details: nil)
    case code.to_i
    when 131_037
      I18n.t('conversations.messages.whatsapp.errors.display_name_not_approved')
    when 131_049
      I18n.t('conversations.messages.whatsapp.errors.marketing_limit_reached')
    when 131_042
      I18n.t('conversations.messages.whatsapp.errors.payment_issue')
    when 131_053
      I18n.t('conversations.messages.whatsapp.errors.media_format_not_supported')
    else
      if details.present?
        "#{code}: #{details}"
      else
        I18n.t('conversations.messages.delivery_status.error_code', error_code: code)
      end
    end
  end

  def humanize_from_status_error(error)
    return if error.blank?

    code = error[:code] || error['code']
    title = error[:title] || error['title']
    humanize(code: code, details: title)
  end
end
