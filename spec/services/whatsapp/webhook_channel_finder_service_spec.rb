# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::WebhookChannelFinderService do
  let(:account) { create(:account) }
  let!(:channel) do
    ch = create(
      :channel_whatsapp,
      account: account,
      phone_number: '+554187814116',
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
    ch.update_columns( # rubocop:disable Rails/SkipsModelValidations
      provider_config: ch.provider_config.merge(
        'phone_number_id' => '832656013256861',
        'business_account_id' => '1432484038007576'
      )
    )
    ch
  end

  it 'finds channel by exact display phone digits' do
    found = described_class.new(
      display_phone_number: '554187814116',
      phone_number_id: '832656013256861'
    ).perform

    expect(found).to eq(channel)
  end

  it 'finds channel when Meta omits the Brazilian mobile 9th digit' do
    channel.update_columns(phone_number: '+5541987814116') # rubocop:disable Rails/SkipsModelValidations

    found = described_class.new(
      display_phone_number: '554187814116',
      phone_number_id: '832656013256861'
    ).perform

    expect(found).to eq(channel)
  end

  it 'returns nil when phone_number_id does not match' do
    found = described_class.new(
      display_phone_number: '554187814116',
      phone_number_id: 'wrong-id'
    ).perform

    expect(found).to be_nil
  end

  it 'returns nil when display phone is blank' do
    found = described_class.new(
      display_phone_number: '',
      phone_number_id: '832656013256861'
    ).perform

    expect(found).to be_nil
  end
end
