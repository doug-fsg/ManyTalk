# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::ErrorHumanizer do
  describe '.humanize' do
    it 'returns marketing limit message for error 131049' do
      expect(described_class.humanize(code: 131_049)).to eq(
        I18n.t('conversations.messages.whatsapp.errors.marketing_limit_reached')
      )
    end

    it 'returns display name message for error 131037' do
      expect(described_class.humanize(code: 131_037)).to eq(
        I18n.t('conversations.messages.whatsapp.errors.display_name_not_approved')
      )
    end

    it 'falls back to code and details for unknown codes' do
      expect(described_class.humanize(code: 999, details: 'Unknown error')).to eq('999: Unknown error')
    end
  end

  describe '.humanize_from_status_error' do
    it 'humanizes webhook status errors' do
      error = { code: 131_049, title: 'Healthy ecosystem engagement' }

      expect(described_class.humanize_from_status_error(error)).to eq(
        I18n.t('conversations.messages.whatsapp.errors.marketing_limit_reached')
      )
    end
  end
end
