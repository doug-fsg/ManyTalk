# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::PhoneNormalizer do
  describe '.normalize' do
    it 'normalizes brazilian mobile with ddd' do
      expect(described_class.normalize('11999999999')).to eq('+5511999999999')
    end

    it 'keeps international e164' do
      expect(described_class.normalize('+1234567890')).to eq('+1234567890')
    end

    it 'returns nil for blank input' do
      expect(described_class.normalize('')).to be_nil
    end
  end

  describe '#jid' do
    it 'builds whatsapp jid from normalized phone' do
      normalizer = described_class.new('11999999999')
      expect(normalizer.jid).to eq('5511999999999@s.whatsapp.net')
    end
  end
end
