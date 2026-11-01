# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendantConfig do
  it 'allows the same config to link multiple inboxes' do
    account = create(:account)
    inbox_a = create(:inbox, account: account)
    inbox_b = create(:inbox, account: account)
    config = create(:ai_attendant_config, account: account, inbox_ids: [inbox_a.id])
    create(:ai_attendant_config_inbox, ai_attendant_config: config, inbox_id: inbox_b.id)

    expect(config.reload.inbox_ids).to contain_exactly(inbox_a.id, inbox_b.id)
  end

  it 'does not allow the same inbox on two configs' do
    account = create(:account)
    inbox = create(:inbox, account: account)
    create(:ai_attendant_config, account: account, inbox_id: inbox.id)
    other = create(:ai_attendant_config, account: account)
    link = build(:ai_attendant_config_inbox, ai_attendant_config: other, inbox_id: inbox.id)

    expect(link).not_to be_valid
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:sender_agent_bot).class_name('AgentBot').optional }
    it { is_expected.to have_many(:ai_attendant_config_inboxes).dependent(:destroy) }
    it { is_expected.to have_many(:inboxes).through(:ai_attendant_config_inboxes) }
    it { is_expected.to have_many_attached(:reference_files) }
  end

  describe 'validations' do
    it {
      expect(subject).to validate_inclusion_of(:avatar_id).in_array(
        %w[avatar_1 avatar_2 avatar_3 avatar_4 avatar_5 avatar_6]
      )
    }

    it {
      expect(subject).to validate_inclusion_of(:schedule_mode).in_array(
        %w[always within_inbox_hours outside_inbox_hours]
      )
    }

    it {
      expect(subject).to validate_inclusion_of(:pause_reason).in_array(%w[no_credits admin]).allow_nil
    }

    it {
      expect(subject).to validate_numericality_of(:debounce_seconds)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(30)
    }

    it 'accepts debounce_seconds of 1 and 30' do
      expect(build(:ai_attendant_config, debounce_seconds: 1)).to be_valid
      expect(build(:ai_attendant_config, debounce_seconds: 30)).to be_valid
    end

    it 'rejects debounce_seconds of 0, -1, and 31' do
      expect(build(:ai_attendant_config, debounce_seconds: 0)).not_to be_valid
      expect(build(:ai_attendant_config, debounce_seconds: -1)).not_to be_valid
      expect(build(:ai_attendant_config, debounce_seconds: 31)).not_to be_valid
    end
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
      inbox_a = create(:inbox, account: account)
      inbox_b = create(:inbox, account: account)
      matching = create(:ai_attendant_config, account: account, inbox_id: inbox_a.id)
      create(:ai_attendant_config, account: account, inbox_id: inbox_b.id)

      expect(described_class.for_inbox(inbox_a.id)).to contain_exactly(matching)
    end
  end
end
