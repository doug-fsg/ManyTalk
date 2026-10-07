# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPolicy, type: :policy do
  subject(:policy) { described_class.new(policy_context(user, account), Contact) }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }

  before { account.enable_features!('custom_roles') }

  context 'when the agent has a custom role without contact_manage' do
    before do
      custom_role = create(:custom_role, account: account, permissions: ['report_manage'])
      account_user_for(user, account).update!(custom_role: custom_role)
    end

    it 'denies contact list access' do
      expect(policy.index?).to be(false)
    end

    it 'denies contact updates' do
      expect(policy.update?).to be(false)
    end
  end

  context 'when the agent has contact_manage in the custom role' do
    before do
      custom_role = create(:custom_role, account: account, permissions: ['contact_manage'])
      account_user_for(user, account).update!(custom_role: custom_role)
    end

    it 'allows contact list access' do
      expect(policy.index?).to be(true)
    end
  end

  context 'when the agent has no custom role' do
    it 'keeps default agent contact access' do
      expect(policy.index?).to be(true)
    end
  end
end
