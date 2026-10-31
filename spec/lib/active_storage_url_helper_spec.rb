# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveStorageUrlHelper do
  describe '.url_for_attachment' do
    it 'returns a relative path when only_path is true' do
      ActiveStorage::Current.url_options = { protocol: 'http', host: 'example.com', port: 3002 }
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('test'),
        filename: 'test.txt',
        content_type: 'text/plain'
      )
      attachment = ActiveStorage::Attachment.new(blob: blob, name: 'file')

      url = described_class.url_for_attachment(attachment, only_path: true)

      expect(url).to start_with('/rails/active_storage/')
      expect(url).not_to include('example.com')
    end
  end
end
