# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Messages::LiquidInterpolatorService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'maria silva') }
  let(:agent) { create(:user, account: account, name: 'john agent') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  subject(:interpolator) do
    described_class.new(conversation: conversation, sender: agent)
  end

  it 'interpolates contact variables in a string' do
    result = interpolator.interpolate('Olá {{contact.last_name}}')
    expect(result).to eq('Olá Silva')
  end

  it 'interpolates nested processed params' do
    params = {
      'body' => { '1' => 'Olá {{contact.first_name}}' },
      'buttons' => [{ 'parameter' => '{{contact.name}}' }]
    }

    result = interpolator.interpolate_value(params)
    expect(result['body']['1']).to eq('Olá Maria')
    expect(result['buttons'].first['parameter']).to eq('Maria Silva')
  end

  it 'returns original text when liquid syntax is invalid' do
    result = interpolator.interpolate('broken {{contact.email')
    expect(result).to eq('broken {{contact.email')
  end
end
