# frozen_string_literal: true

# Synchronous HTTP client for AI intent classification.
# Strangler: does not touch Webhooks::Trigger or WebhookJob.
module Workflows
  class SyncWebhookClient
    TIMEOUT = ENV.fetch('WEBHOOKS_TRIGGER_TIMEOUT', 5).to_i
    MAX_RESPONSE_BYTES = 64.kilobytes

    # Returns a structured result hash:
    #   { ok: true,  matched: true|false, raw: {...} }
    #   { ok: false, matched: false, error: :timeout|:http_error|:invalid_json }
    def self.post_json(url, payload, timeout: TIMEOUT)
      new(url, payload, timeout: timeout).call
    end

    def initialize(url, payload, timeout:)
      @url = url
      @payload = payload
      @timeout = timeout
    end

    def call
      response = RestClient::Request.execute(
        method: :post,
        url: @url,
        payload: @payload.to_json,
        timeout: @timeout,
        headers: { content_type: :json, accept: :json }
      )
      parse_response(response)
    rescue RestClient::Exceptions::Timeout
      Rails.logger.warn("[SyncWebhookClient] timeout after #{@timeout}s")
      { ok: false, matched: false, error: :timeout }
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.warn("[SyncWebhookClient] HTTP #{e.http_code}")
      { ok: false, matched: false, error: :http_error }
    rescue StandardError => e
      Rails.logger.warn("[SyncWebhookClient] error: #{e.class} #{e.message}")
      { ok: false, matched: false, error: :http_error }
    end

    private

    def parse_response(response)
      body = response.body.to_s
      body = body.byteslice(0, MAX_RESPONSE_BYTES) if body.bytesize > MAX_RESPONSE_BYTES

      data = JSON.parse(body)
      matched = ActiveModel::Type::Boolean.new.cast(data['matched']) == true
      { ok: true, matched: matched, raw: data }
    rescue JSON::ParserError
      { ok: false, matched: false, error: :invalid_json }
    end
  end
end
