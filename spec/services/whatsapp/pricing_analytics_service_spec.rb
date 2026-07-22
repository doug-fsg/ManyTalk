# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::PricingAnalyticsService do
  subject(:service) { described_class.new(whatsapp_channel) }

  let(:whatsapp_channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      validate_provider_config: false,
      sync_templates: false,
      provider_config: {
        'api_key' => 'test_key',
        'phone_number_id' => '123456789',
        'business_account_id' => 'waba_123'
      }
    )
  end

  let(:pricing_response) do
    {
      'pricing_analytics' => {
        'data' => [
          {
            'data_points' => [
              {
                'pricing_category' => 'MARKETING',
                'volume' => 10,
                'cost' => 5.5
              },
              {
                'pricing_category' => 'UTILITY',
                'volume' => 4,
                'cost' => 1.2
              },
              {
                'pricing_category' => 'SERVICE',
                'volume' => 20,
                'cost' => 0
              }
            ]
          }
        ]
      }
    }
  end

  describe '#fetch_monthly_summary' do
    it 'aggregates monthly pricing analytics by category' do
      stub_request(:get, %r{graph\.facebook\.com/.+/waba_123})
        .with(query: hash_including(access_token: 'test_key'))
        .to_return(status: 200, body: pricing_response.to_json, headers: { 'Content-Type' => 'application/json' })

      summary = service.fetch_monthly_summary

      expect(summary[:total_cost]).to eq(6.7)
      expect(summary[:total_volume]).to eq(34)
      expect(summary[:cost_available]).to be(true)
      expect(summary[:categories]).to include(
        hash_including(key: 'MARKETING', cost: 5.5, volume: 10),
        hash_including(key: 'UTILITY', cost: 1.2, volume: 4)
      )
    end

    it 'raises a friendly message when cost is unavailable' do
      stub_request(:get, %r{graph\.facebook\.com/.+/waba_123})
        .to_return(
          status: 400,
          body: {
            error: {
              message: 'Cost not available',
              error_data: { details: 'Cost is no longer shown for businesses who bill through a partner' }
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect { service.fetch_monthly_summary }.to raise_error(
        Whatsapp::PricingAnalyticsService::CostUnavailableError,
        I18n.t('conversations.messages.whatsapp.pricing.cost_unavailable')
      )
    end
  end
end
