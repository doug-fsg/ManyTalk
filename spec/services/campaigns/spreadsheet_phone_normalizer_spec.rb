# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::SpreadsheetPhoneNormalizer do
  describe '.normalize_to_e164' do
    it 'keeps international numbers that start with +' do
      expect(described_class.normalize_to_e164('+1234567890')).to eq('+1234567890')
      expect(described_class.normalize_to_e164('+1 (234) 567-890')).to eq('+1234567890')
    end

    it 'prepends country 55 to local Brazilian numbers without rewriting the ninth digit' do
      expect(described_class.normalize_to_e164('11999999999')).to eq('+5511999999999')
      expect(described_class.normalize_to_e164('1199999999')).to eq('+551199999999')
      expect(described_class.normalize_to_e164('5599067484')).to eq('+555599067484')
      expect(described_class.normalize_to_e164('55999067484')).to eq('+5555999067484')
    end

    it 'keeps already-international Brazilian digits' do
      expect(described_class.normalize_to_e164('5555999067484')).to eq('+5555999067484')
      expect(described_class.normalize_to_e164('+555599067484')).to eq('+555599067484')
    end

    it 'returns nil for blank or too-short values' do
      expect(described_class.normalize_to_e164('')).to be_nil
      expect(described_class.normalize_to_e164(nil)).to be_nil
    end
  end

  describe '.normalize_to_jid' do
    it 'returns JID from canonical E.164' do
      expect(described_class.normalize_to_jid('11999999999')).to eq('5511999999999@s.whatsapp.net')
    end
  end
end
