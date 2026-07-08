# frozen_string_literal: true

class Whatsapp::WebhookSetupService
  def initialize(channel, waba_id = nil, access_token = nil)
    @channel = channel
    @waba_id = waba_id || channel.provider_config['business_account_id']
    @access_token = access_token || channel.provider_config['api_key']
    @api_client = Whatsapp::FacebookApiClient.new(@access_token)
  end

  def perform
    validate_parameters!

    register_phone_number
    setup_webhook
  end

  def register_callback
    validate_parameters!
    setup_webhook
  end

  def register_phone!
    validate_parameters!
    register_phone_number(raise_on_failure: true)
  end

  private

  def validate_parameters!
    raise ArgumentError, 'Channel is required' if @channel.blank?
    raise ArgumentError, 'WABA ID is required' if @waba_id.blank?
    raise ArgumentError, 'Access token is required' if @access_token.blank?
    raise ArgumentError, 'Phone number ID is required' if @channel.provider_config['phone_number_id'].blank?
  end

  def register_phone_number(raise_on_failure: false)
    phone_number_id = @channel.provider_config['phone_number_id']
    pin = fetch_or_create_pin

    @api_client.register_phone_number(phone_number_id, pin)
    store_pin(pin)
    Rails.logger.info("[WHATSAPP] Phone number #{phone_number_id} registered for Cloud API")
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Phone registration failed: #{e.message}")
    raise e if raise_on_failure
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
    phone_number_id = @channel.provider_config['phone_number_id']

    @api_client.subscribe_phone_number_webhook(
      @waba_id,
      phone_number_id,
      callback_url,
      verify_token,
      subscribed_fields: subscribed_fields
    )
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Webhook setup failed: #{e.message}")
    raise "Webhook setup failed: #{e.message}"
  end

  def subscribed_fields
    %w[messages smb_message_echoes]
  end

  def build_callback_url
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    phone_number = @channel.phone_number

    "#{frontend_url}/webhooks/whatsapp/#{phone_number}"
  end
end
