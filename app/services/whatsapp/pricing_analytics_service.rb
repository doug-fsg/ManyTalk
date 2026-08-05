# frozen_string_literal: true

class Whatsapp::PricingAnalyticsService
  class CostUnavailableError < StandardError; end

  BASE_URI = 'https://graph.facebook.com'.freeze

  def initialize(channel)
    @channel = channel
    @access_token = channel.provider_config['api_key']
    @waba_id = channel.provider_config['business_account_id']
    @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def fetch_monthly_summary
    validate_channel!

    period_start = Time.zone.now.beginning_of_month
    period_end = Time.zone.now
    include_cost = !partner_billing_account?

    response = fetch_with_cost_fallback(period_start.to_i, period_end.to_i, include_cost: include_cost)
    build_summary(response, period_start, period_end)
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP PRICING] Error fetching pricing data: #{e.message}"
    raise e
  end

  private

  def validate_channel!
    raise ArgumentError, 'Channel is required' if @channel.blank?
    raise ArgumentError, 'API key is missing' if @access_token.blank?
    raise ArgumentError, 'WhatsApp Business Account ID is missing' if @waba_id.blank?
  end

  def fetch_with_cost_fallback(start_time, end_time, include_cost:)
    fetch_pricing_analytics(start_time, end_time, include_cost: include_cost)
  rescue CostUnavailableError
    fetch_pricing_analytics(start_time, end_time, include_cost: false)
  end

  def fetch_pricing_analytics(start_time, end_time, include_cost: true)
    metric_types = include_cost ? 'COST,VOLUME' : 'VOLUME'
    fields = [
      'pricing_analytics',
      ".start(#{start_time})",
      ".end(#{end_time})",
      '.granularity(MONTHLY)',
      ".metric_types(#{metric_types})",
      '.dimensions(PRICING_CATEGORY)'
    ].join

    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{@waba_id}",
      query: {
        fields: fields,
        access_token: @access_token
      }
    )

    handle_response(response)
  end

  def handle_response(response)
    unless response.success?
      error_message = parse_error_message(response)
      raise error_message
    end

    response.parsed_response
  end

  def parse_error_message(response)
    parsed = response.parsed_response
    error = parsed.is_a?(Hash) ? parsed['error'] : nil
    return "WhatsApp API request failed: #{response.code} - #{response.body}" if error.blank?

    if cost_unavailable_error?(error)
      raise CostUnavailableError, I18n.t('conversations.messages.whatsapp.pricing.cost_unavailable')
    end

    error['error_user_msg'] || error['message'] || response.body
  end

  def partner_billing_account?
    @channel.provider_config['source'] == 'embedded_signup'
  end

  def cost_unavailable_error?(error)
    return false if error.blank?

    combined = [
      error['message'],
      error['error_user_msg'],
      error.dig('error_data', 'details'),
      error.dig('error_data', 'message')
    ].compact.join(' ').downcase

    combined.include?('cost not available') ||
      combined.include?('cost is not shown') ||
      combined.include?('bill through a partner') ||
      combined.include?('solution partner')
  end

  def build_summary(response, period_start, period_end)
    data_points = extract_data_points(response)
    categories = aggregate_categories(data_points)
    cost_available = data_points.any? { |point| point.key?('cost') && !point['cost'].nil? }
    total_cost = categories.sum { |category| category[:cost] }
    total_volume = categories.sum { |category| category[:volume] }

    {
      period_start: period_start.iso8601,
      period_end: period_end.iso8601,
      total_cost: total_cost.round(4),
      total_volume: total_volume,
      cost_available: cost_available,
      categories: categories,
      waba_id: @channel.provider_config['business_account_id']
    }
  end

  def extract_data_points(response)
    analytics_data = response.dig('pricing_analytics', 'data') || []
    analytics_data.flat_map { |entry| entry['data_points'] || [] }
  end

  def aggregate_categories(data_points)
    grouped = data_points.group_by { |point| point['pricing_category'] || 'UNKNOWN' }
    cost_available = data_points.any? { |point| point.key?('cost') && !point['cost'].nil? }
    sort_key = cost_available ? :cost : :volume

    grouped.map do |category, points|
      {
        key: category,
        cost: points.sum { |point| point['cost'].to_f }.round(4),
        volume: points.sum { |point| point['volume'].to_i }
      }
    end.sort_by { |category| -category[sort_key] }
  end
end
