# frozen_string_literal: true

module CustomExceptions::ContactMerge
  class InvalidMerge < CustomExceptions::Base
    def message
      @data[:message] || I18n.t('contacts.merge.errors.invalid')
    end

    def http_status
      422
    end
  end
end
