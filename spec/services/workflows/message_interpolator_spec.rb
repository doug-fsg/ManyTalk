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

  it 'returns empty string for unknown variables' do
    result = described_class.new(conversation).interpolate('{{unknown.field}}')
    expect(result).to eq('')
  end
end
