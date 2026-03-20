# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::SpreadsheetPhoneNormalizer do
  describe '.normalize_to_e164' do
    context 'with international numbers (starting with +)' do
      it 'returns E.164 format without applying DDD rules' do
        expect(described_class.normalize_to_e164('+1234567890')).to eq('+1234567890')
      end

      it 'removes non-digit characters' do
        expect(described_class.normalize_to_e164('+1 (234) 567-890')).to eq('+1234567890')
      end
    end

    context 'with Brazilian numbers' do
      context 'when DDD < 31 (10 digits)' do
        it 'adds 9 after DDD' do
          expect(described_class.normalize_to_e164('1199999999')).to eq('+5511999999999')
        end

        it 'handles DDD 21 (Rio)' do
          expect(described_class.normalize_to_e164('2198765432')).to eq('+5521987654329')
        end
      end

      context 'when DDD < 31 (11 digits)' do
        it 'keeps the 9' do
          expect(described_class.normalize_to_e164('11999999999')).to eq('+5511999999999')
        end
      end

      context 'when DDD >= 31 (10 digits)' do
        it 'does not add 9' do
          expect(described_class.normalize_to_e164('3112345678')).to eq('+553112345678')
        end

        it 'handles DDD 85 (Fortaleza)' do
          expect(described_class.normalize_to_e164('8598765432')).to eq('+558598765432')
        end
      end

      context 'when DDD >= 31 (11 digits)' do
        it 'removes the 9' do
          expect(described_class.normalize_to_e164('31912345678')).to eq('+553112345678')
        end
      end

      context 'with 12 digits starting with 55' do
        it 'normalizes correctly' do
          expect(described_class.normalize_to_e164('5511999999999')).to eq('+5511999999999')
        end
      end

      context 'with special characters' do
        it 'removes formatting and normalizes' do
          expect(described_class.normalize_to_e164('(11) 99999-9999')).to eq('+5511999999999')
        end

        it 'handles various formats' do
          expect(described_class.normalize_to_e164('11 9 9999 9999')).to eq('+5511999999999')
        end
      end
    end

    context 'with invalid numbers' do
      it 'returns nil for empty string' do
        expect(described_class.normalize_to_e164('')).to be_nil
      end

      it 'returns nil for nil' do
        expect(described_class.normalize_to_e164(nil)).to be_nil
      end

      it 'returns nil for too short numbers (less than 10 digits for Brazil)' do
        expect(described_class.normalize_to_e164('119999999')).to be_nil
      end
    end
  end

  describe '.normalize_to_jid' do
    it 'returns JID format for international numbers' do
      expect(described_class.normalize_to_jid('+1234567890')).to eq('1234567890@s.whatsapp.net')
    end

    it 'returns JID format for Brazilian numbers' do
      expect(described_class.normalize_to_jid('1199999999')).to eq('5511999999999@s.whatsapp.net')
    end

    it 'returns nil for invalid numbers' do
      expect(described_class.normalize_to_jid('')).to be_nil
      expect(described_class.normalize_to_jid('123')).to be_nil
    end
  end
end
