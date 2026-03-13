# frozen_string_literal: true

class Whatsapp::WebhookSetupService
  def initialize(channel, waba_id, access_token)
    @channel = channel
    @waba_id = waba_id
    @access_token = access_token
    @api_client = Whatsapp::FacebookApiClient.new(access_token)
  end

  def perform
    validate_parameters!

    register_phone_number if !phone_number_verified? || phone_number_needs_registration?

    setup_webhook
  end

  private

  def validate_parameters!
    raise ArgumentError, 'Channel is required' if @channel.blank?
    raise ArgumentError, 'WABA ID is required' if @waba_id.blank?
    raise ArgumentError, 'Access token is required' if @access_token.blank?
  end

  def register_phone_number
    phone_number_id = @channel.provider_config['phone_number_id']
    pin = fetch_or_create_pin

    @api_client.register_phone_number(phone_number_id, pin)
    store_pin(pin)
  rescue StandardError => e
    Rails.logger.warn("[WHATSAPP] Phone registration failed but continuing: #{e.message}")
  end

  def fetch_or_create_pin
    existing_pin = @channel.provider_config['verification_pin']
    return existing_pin.to_i if existing_pin.present?

    SecureRandom.random_number(900_000) + 100_000
  end

  def store_pin(pin)
    @channel.provider_config['verification_pin'] = pin
    @channel.save!
  end

  def setup_webhook
    callback_url = build_callback_url
    verify_token = @channel.provider_config['webhook_verify_token']

    @api_client.subscribe_waba_webhook(@waba_id, callback_url, verify_token)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Webhook setup failed: #{e.message}")
    raise "Webhook setup failed: #{e.message}"
  end

  def build_callback_url
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    phone_number = @channel.phone_number

    "#{frontend_url}/webhooks/whatsapp/#{phone_number}"
  end

  def phone_number_verified?
    phone_number_id = @channel.provider_config['phone_number_id']

    verified = @api_client.phone_number_verified?(phone_number_id)
    Rails.logger.info("[WHATSAPP] Phone number #{phone_number_id} code verification status: #{verified}")

    verified
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Phone verification status check failed: #{e.message}")
    false
  end

  def phone_number_needs_registration?
    phone_number_in_pending_state?
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Phone registration check failed: #{e.message}")
    false
  end

  def phone_number_in_pending_state?
    health_service = Whatsapp::HealthService.new(@channel)
    health_data = health_service.fetch_health_status

    health_data[:platform_type] == 'NOT_APPLICABLE' ||
      health_data.dig(:throughput, :level) == 'NOT_APPLICABLE'
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Health status check failed: #{e.message}")
    false
  end
end
