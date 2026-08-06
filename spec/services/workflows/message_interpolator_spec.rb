# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::MessageInterpolator do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Maria Silva', email: 'maria@example.com') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  it 'interpolates contact variables' do
    result = described_class.new(conversation).interpolate('Olá {{contact.first_name}}!')
    expect(result).to eq('Olá Maria!')
  end

  it 'supports contact.phone alias and last_name' do
    contact.update!(phone_number: '+5511999999999')
    result = described_class.new(conversation).interpolate(
      '{{contact.last_name}} {{contact.phone}}'
    )
    expect(result).to eq('Silva +5511999999999')
  end

  it 'returns empty string for unknown variables' do
    result = described_class.new(conversation).interpolate('{{unknown.field}}')
    expect(result).to eq('')
  end
end
