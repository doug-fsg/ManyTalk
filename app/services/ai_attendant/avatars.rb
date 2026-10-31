# frozen_string_literal: true

module AiAttendant
  class Avatars
    IDS = %w[avatar_1 avatar_2 avatar_3 avatar_4 avatar_5 avatar_6].freeze
    DEFAULT_ID = 'avatar_1'
    FILENAME = '%<id>s.png'
    PUBLIC_DIR = Rails.root.join('public/ai_attendant/avatars')

    class << self
      def valid?(id)
        IDS.include?(id.to_s)
      end

      def path_for(id)
        return unless valid?(id)

        PUBLIC_DIR.join(format(FILENAME, id: id))
      end

      def url_for(id)
        key = valid?(id) ? id.to_s : DEFAULT_ID
        "/ai_attendant/avatars/#{format(FILENAME, id: key)}"
      end
    end
  end
end
