# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::PricingAnalyticsService do
  subject(:service) { described_class.new(whatsapp_channel) }

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:setup_webhooks)
  end

  let(:whatsapp_channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      validate_provider_config: false,
      sync_templates: false,
      skip_webhook_setup: false,
      provider_config: {
        'api_key' => 'test_key',
        'phone_number_id' => '123456789',
        'business_account_id' => '123456789'
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
      stub_request(:get, %r{graph\.facebook\.com/.+/123456789})
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
      stub_request(:get, %r{graph\.facebook\.com/.+/123456789})
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

    it 'raises a friendly message for Meta BSP billing errors in error message' do
      stub_request(:get, %r{graph\.facebook\.com/.+/123456789})
        .to_return(
          status: 400,
          body: {
            error: {
              message: 'COST is not shown for businesses who bill through a partner (i.e., BSP). To understand your charges, please reach out to your partner.'
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect { service.fetch_monthly_summary }.to raise_error(
        Whatsapp::PricingAnalyticsService::CostUnavailableError,
        I18n.t('conversations.messages.whatsapp.pricing.cost_unavailable')
      )
    end

    it 'fetches volume-only analytics for embedded signup channels' do
      whatsapp_channel.update!(
        provider_config: whatsapp_channel.provider_config.merge('source' => 'embedded_signup')
      )

      stub_request(:get, %r{graph\.facebook\.com/.+/123456789})
        .with(query: hash_including(access_token: 'test_key'))
        .to_return(
          status: 200,
          body: {
            pricing_analytics: {
              data: [
                {
                  data_points: [
                    { pricing_category: 'MARKETING', volume: 12 },
                    { pricing_category: 'UTILITY', volume: 5 }
                  ]
                }
              ]
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      summary = service.fetch_monthly_summary

      expect(summary[:total_volume]).to eq(17)
      expect(summary[:cost_available]).to be(false)
      expect(a_request(:get, %r{graph\.facebook\.com/.+/123456789})
        .with(query: hash_including(access_token: 'test_key'))).to have_been_made.once
    end
  end
end
