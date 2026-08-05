# frozen_string_literal: true

class Whatsapp::HealthService
  BASE_URI = 'https://graph.facebook.com'.freeze

  def initialize(channel)
    @channel = channel
    @access_token = channel.provider_config['api_key']
    @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def fetch_health_status
    validate_channel!
    ensure_meta_business_id!
    fetch_phone_health_data
  end

  private

  def validate_channel!
    raise ArgumentError, 'Channel is required' if @channel.blank?
    raise ArgumentError, 'API key is missing' if @access_token.blank?
    raise ArgumentError, 'Phone number ID is missing' if @channel.provider_config['phone_number_id'].blank?
  end

  def waba_id
    @channel.provider_config['business_account_id']
  end

  def meta_business_id
    @channel.provider_config['meta_business_id']
  end

  # Older channels (and buggy reauth) may miss meta_business_id.
  # Fetch owner portfolio ID from WABA and persist it — no reconnect needed.
  def ensure_meta_business_id!
    return if meta_business_id.present?
    return if waba_id.blank?

    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{waba_id}",
      query: {
        fields: 'owner_business_info',
        access_token: @access_token
      }
    )
    return unless response.success?

    owner_id = response.dig('owner_business_info', 'id')
    return if owner_id.blank?

    config = @channel.provider_config.merge('meta_business_id' => owner_id)
    @channel.update_column(:provider_config, config) # rubocop:disable Rails/SkipsModelValidations
    @channel.reload
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP HEALTH] Could not backfill meta_business_id: #{e.message}"
  end

  def fetch_phone_health_data
    phone_number_id = @channel.provider_config['phone_number_id']

    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      query: {
        fields: health_fields,
        access_token: @access_token
      }
    )

    handle_response(response)
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP HEALTH] Error fetching health data: #{e.message}"
    raise e
  end

  def health_fields
    %w[
      quality_rating
      messaging_limit_tier
      code_verification_status
      account_mode
      id
      display_phone_number
      name_status
      verified_name
      webhook_configuration
      throughput
      last_onboarded_time
      platform_type
      certificate
    ].join(',')
  end

  def handle_response(response)
    unless response.success?
      error_message = "WhatsApp API request failed: #{response.code} - #{response.body}"
      Rails.logger.error "[WHATSAPP HEALTH] #{error_message}"
      raise error_message
    end

    data = response.parsed_response
    format_health_response(data)
  end

  def format_health_response(response)
    {
      id: response['id'],
      display_phone_number: response['display_phone_number'],
      verified_name: response['verified_name'],
      name_status: response['name_status'],
      quality_rating: response['quality_rating'],
      messaging_limit_tier: response['messaging_limit_tier'],
      account_mode: response['account_mode'],
      code_verification_status: response['code_verification_status'],
      webhook_configuration: response['webhook_configuration'],
      expected_webhook_url: build_expected_webhook_url,
      throughput: response['throughput'],
      last_onboarded_time: response['last_onboarded_time'],
      platform_type: response['platform_type'],
      certificate: response['certificate'],
      business_id: meta_business_id,
      waba_id: waba_id
    }
  end

  def build_expected_webhook_url
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    return nil if frontend_url.blank?

    "#{frontend_url}/webhooks/whatsapp/#{@channel.phone_number}"
  end
end
