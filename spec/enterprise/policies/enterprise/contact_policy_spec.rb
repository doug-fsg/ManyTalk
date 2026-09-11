# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPolicy, type: :policy do
  subject(:policy) { described_class.new(account_user, Contact) }

  let(:account) { create(:account) }

  before { account.enable_features!('custom_roles') }

  context 'when the agent has a custom role without contact_manage' do
    let(:account_user) do
      user = create(:user, account: account, role: :agent)
      custom_role = create(:custom_role, account: account, permissions: ['report_manage'])
      user.current_account_user.update!(custom_role: custom_role)
      user.current_account_user
    end

    it 'denies contact list access' do
      expect(policy.index?).to be(false)
    end

    it 'denies contact updates' do
      expect(policy.update?).to be(false)
    end
  end

  context 'when the agent has contact_manage in the custom role' do
    let(:account_user) do
      user = create(:user, account: account, role: :agent)
      custom_role = create(:custom_role, account: account, permissions: ['contact_manage'])
      user.current_account_user.update!(custom_role: custom_role)
      user.current_account_user
    end

    it 'allows contact list access' do
      expect(policy.index?).to be(true)
    end
  end

  context 'when the agent has no custom role' do
    let(:account_user) { create(:user, account: account, role: :agent).current_account_user }

    it 'keeps default agent contact access' do
      expect(policy.index?).to be(true)
    end
  end
end
