# frozen_string_literal: true

module PlatformAi
  class ChatClient
    API_URL = 'https://api.openai.com/v1/chat/completions'
    DEFAULT_MODEL = 'gpt-4.1-nano'
    DEFAULT_TIMEOUT = 30

    class RequestError < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        @status = status
        @body = body
        super(message)
      end
    end

    def self.complete(messages:, tools: nil, model: nil)
      new.complete(messages: messages, tools: tools, model: model)
    end

    def complete(messages:, tools: nil, model: nil)
      payload = {
        model: resolve_model(model),
        messages: messages
      }
      payload[:tools] = tools if tools.present?

      response = HTTParty.post(
        API_URL,
        headers: request_headers,
        body: payload.to_json,
        timeout: DEFAULT_TIMEOUT
      )

      raise_unless_success!(response)
      parse_response(response)
    end

    private

    def resolve_model(model)
      model.presence || ENV['PLATFORM_AI_MODEL'].presence || DEFAULT_MODEL
    end

    def request_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV.fetch('OPENAI_API_KEY')}"
      }
    end

    def raise_unless_success!(response)
      return if response.success?

      raise RequestError.new(
        "OpenAI chat completion failed with HTTP #{response.code}",
        status: response.code,
        body: response.body
      )
    end

    def parse_response(response)
      body = response.parsed_response
      body = JSON.parse(response.body) unless body.is_a?(Hash)
      message = body.dig('choices', 0, 'message') || {}

      {
        content: message['content'],
        tool_calls: message['tool_calls'],
        total_tokens: body.dig('usage', 'total_tokens')
      }
    end
  end
end
