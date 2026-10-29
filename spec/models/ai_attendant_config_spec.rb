# frozen_string_literal: true

require 'rails_helper'

# Model spec for per-inbox native AI attendant configuration.

RSpec.describe AiAttendantConfig do
  it 'requires unique inbox_id per account' do
    account = create(:account)
    create(:ai_attendant_config, account: account, inbox_id: 1)
    dup = build(:ai_attendant_config, account: account, inbox_id: 1)
    expect(dup).not_to be_valid
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:sender_user).class_name('User').optional }
    it { is_expected.to have_many_attached(:reference_files) }
  end

  describe 'validations' do
    it {
      expect(subject).to validate_inclusion_of(:schedule_mode).in_array(
        %w[always within_inbox_hours outside_inbox_hours]
      )
    }

    it {
      expect(subject).to validate_inclusion_of(:pause_reason).in_array(%w[no_credits admin]).allow_nil
    }

    it { is_expected.to validate_numericality_of(:debounce_seconds).is_less_than_or_equal_to(30) }
  end

  describe 'defaults' do
    it 'defaults active to false and debounce_seconds to 5' do
      config = create(:ai_attendant_config)
      expect(config.active).to be false
      expect(config.debounce_seconds).to eq 5
    end
  end

  describe '.for_inbox' do
    it 'returns configs for the given inbox_id' do
      account = create(:account)
      matching = create(:ai_attendant_config, account: account, inbox_id: 10)
      create(:ai_attendant_config, account: account, inbox_id: 11)

      expect(described_class.for_inbox(10)).to contain_exactly(matching)
    end
  end
end
# nonce 0
