# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformAi::ChatClient do
  let(:api_url) { 'https://api.openai.com/v1/chat/completions' }
  let(:messages) { [{ role: 'user', content: 'olá' }] }
  let(:openai_body) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'oi',
            'tool_calls' => [
              {
                'id' => 'call_1',
                'type' => 'function',
                'function' => { 'name' => 'current_datetime', 'arguments' => '{}' }
              }
            ]
          }
        }
      ],
      'usage' => { 'total_tokens' => 42 }
    }.to_json
  end

  def stub_openai(expected: nil)
    request = stub_request(:post, api_url).to_return(status: 200, body: openai_body, headers: { 'Content-Type' => 'application/json' })
    if expected
      request = request.with { |req| expected.all? { |key, value| JSON.parse(req.body)[key] == value } }
    end
    request
  end

  around do |example|
    with_modified_env('OPENAI_API_KEY' => 'sk-test-platform', 'PLATFORM_AI_MODEL' => nil) { example.run }
  end

  describe '.complete' do
    it 'posts to api.openai.com with the platform key and default model' do
      stub = stub_openai(expected: { 'model' => 'gpt-4.1-nano', 'messages' => [{ 'role' => 'user', 'content' => 'olá' }] })
      stub.with(headers: { 'Authorization' => 'Bearer sk-test-platform', 'Content-Type' => 'application/json' })

      described_class.complete(messages: messages)

      expect(stub).to have_been_requested
    end

    it 'uses PLATFORM_AI_MODEL from ENV when set' do
      stub_openai(expected: { 'model' => 'gpt-4o-mini' })

      with_modified_env('OPENAI_API_KEY' => 'sk-test-platform', 'PLATFORM_AI_MODEL' => 'gpt-4o-mini') do
        described_class.complete(messages: messages)
      end
    end

    it 'uses the explicit model argument over ENV' do
      stub_openai(expected: { 'model' => 'gpt-4.1' })

      described_class.complete(messages: messages, model: 'gpt-4.1')
    end

    it 'includes tools in the request when provided' do
      tools = [{ type: 'function', function: { name: 'handoff_to_human' } }]
      stub_openai(expected: { 'tools' => [{ 'type' => 'function', 'function' => { 'name' => 'handoff_to_human' } }] })

      described_class.complete(messages: messages, tools: tools)
    end

    it 'returns content, tool_calls and total_tokens' do
      stub_openai

      result = described_class.complete(messages: messages)

      expect(result[:content]).to eq('oi')
      expect(result[:tool_calls]).to eq(
        [
          {
            'id' => 'call_1',
            'type' => 'function',
            'function' => { 'name' => 'current_datetime', 'arguments' => '{}' }
          }
        ]
      )
      expect(result[:total_tokens]).to eq(42)
    end

    it 'raises RequestError on non-2xx OpenAI responses' do
      stub_request(:post, api_url).to_return(
        status: 500,
        body: { error: { message: 'internal server error' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      expect { described_class.complete(messages: messages) }
        .to raise_error(PlatformAi::ChatClient::RequestError, /500/)
    end
  end
end
