# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::EnsureSenderUser do
  let(:account) { create(:account) }
  let(:config) do
    create(
      :ai_attendant_config,
      account: account,
      digital_agent_name: 'Lia',
      avatar_id: 'avatar_2'
    )
  end

  def expected_email
    "funcionario-digital-#{account.id}-config-#{config.id}@manytalks.internal"
  end

  describe '.for' do
    it 'creates the bot user for the config when missing' do
      expect do
        described_class.for(config: config)
      end.to change(User, :count).by(1).and change(AccountUser, :count).by(1)

      user = User.from_email(expected_email)
      expect(user).to be_present
      expect(user.name).to eq('Lia')
      expect(user.confirmed?).to be(true)
      expect(user.avatar).to be_attached
    end

    it 'returns the same user on a second call' do
      first = described_class.for(config: config)

      expect do
        second = described_class.for(config: config)
        expect(second.id).to eq(first.id)
      end.not_to change(User, :count)
    end

    it 'updates the display name and avatar when the config changes' do
      user = described_class.for(config: config)
      config.update!(digital_agent_name: 'Carlos', avatar_id: 'avatar_4')

      described_class.for(config: config.reload)
      user.reload

      expect(user.name).to eq('Carlos')
      expect(user.custom_attributes['ai_avatar_id']).to eq('avatar_4')
    end

    it 'links the user as account administrator' do
      user = described_class.for(config: config)

      account_user = user.account_users.find_by!(account: account)
      expect(account_user).to be_administrator
    end
  end
end
