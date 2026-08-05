module Api::V1::Accounts::Concerns::WhatsappHealthManagement
  extend ActiveSupport::Concern

  included do
    skip_before_action :check_authorization, only: [:health, :pricing, :register_webhook, :register_phone]
    before_action :check_admin_authorization?, only: [:register_webhook, :register_phone]
    before_action :validate_whatsapp_cloud_channel, only: [:health, :pricing, :register_webhook, :register_phone]
  end

  def health
    health_data = Whatsapp::HealthService.new(@inbox.channel).fetch_health_status
    render json: health_data
  rescue StandardError => e
    Rails.logger.error "[INBOX HEALTH] Error fetching health data: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def pricing
    pricing_data = Whatsapp::PricingAnalyticsService.new(@inbox.channel).fetch_monthly_summary
    render json: pricing_data
  rescue Whatsapp::PricingAnalyticsService::CostUnavailableError => e
    render json: { error: e.message, error_code: 'partner_billing' }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "[INBOX PRICING] Error fetching pricing data: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def register_webhook
    Whatsapp::WebhookSetupService.new(@inbox.channel).register_callback

    render json: { message: 'Webhook registered successfully' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "[INBOX WEBHOOK] Webhook registration failed: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def register_phone
    Whatsapp::WebhookSetupService.new(@inbox.channel).register_phone!

    render json: { message: 'Phone number registered successfully' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "[INBOX PHONE] Phone registration failed: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def validate_whatsapp_cloud_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Health data only available for WhatsApp Cloud API channels' }, status: :bad_request
  end
end
