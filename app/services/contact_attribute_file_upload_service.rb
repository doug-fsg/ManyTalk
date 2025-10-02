# Service for uploading files for contact custom attributes
# Files are uploaded to a permanent storage location with retention tags
class ContactAttributeFileUploadService
  MAX_FILES_PER_ATTRIBUTE = 5
  STORAGE_PREFIX = 'contact_attachments/'

  def initialize(account:, contact:, attribute_key:)
    @account = account
    @contact = contact
    @attribute_key = attribute_key
  end

  def upload(file)
    validate_file!(file)
    
    blob = create_blob(file)
    add_permanent_tags(blob)
    
    {
      file_url: url_for_blob(blob),
      filename: file.original_filename,
      content_type: file.content_type,
      file_size: file.size,
      blob_key: blob.key,
      blob_id: blob.id,
      uploaded_at: Time.current.iso8601
    }
  end

  def upload_multiple(files)
    return { error: 'Too many files' } if files.size > MAX_FILES_PER_ATTRIBUTE

    files.map { |file| upload(file) }
  end

  def delete(blob_key)
    blob = ActiveStorage::Blob.find_by(key: blob_key)
    return false unless blob

    blob.purge
    true
  end

  private

  def validate_file!(file)
    raise ArgumentError, 'File is required' if file.blank?
    raise ArgumentError, 'File size exceeds limit' if file.size > 10.megabytes
  end

  def create_blob(file)
    # Rewind to ensure we can read the file
    file.rewind if file.respond_to?(:rewind)
    
    # Read file content for checksum
    file_content = file.read
    checksum = Digest::MD5.base64digest(file_content)
    
    # Rewind again after reading
    file.rewind if file.respond_to?(:rewind)
    
    # Create blob and upload directly
    blob = ActiveStorage::Blob.create_and_upload!(
      key: "#{STORAGE_PREFIX}#{SecureRandom.uuid}",
      io: file.is_a?(ActionDispatch::Http::UploadedFile) ? file.tempfile : file,
      filename: file.original_filename,
      content_type: file.content_type,
      metadata: build_metadata
    )
    
    blob
  end

  def build_metadata
    {
      'retention_policy' => 'permanent',
      'type' => 'contact_attribute_file',
      'contact_id' => @contact.id.to_s,
      'account_id' => @account.id.to_s,
      'attribute_key' => @attribute_key
    }
  end

  def add_permanent_tags(blob)
    return unless s3_storage?

    s3_client.put_object_tagging(
      bucket: storage_bucket,
      key: blob.key,
      tagging: {
        tag_set: [
          { key: 'RetentionPolicy', value: 'Permanent' },
          { key: 'Type', value: 'ContactAttachment' },
          { key: 'ContactId', value: @contact.id.to_s },
          { key: 'AccountId', value: @account.id.to_s }
        ]
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to add S3 tags: #{e.message}"
    # Don't fail upload if tagging fails
  end

  def s3_storage?
    service_config = Rails.configuration.active_storage.service_configurations[Rails.configuration.active_storage.service.to_s]
    service_config&.dig('service')&.to_s&.downcase == 's3'
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new
  end

  def storage_bucket
    Rails.configuration.active_storage.service_configurations[Rails.configuration.active_storage.service.to_s]['bucket']
  end

  def url_for_blob(blob)
    Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV['FRONTEND_URL'])
  end
end

