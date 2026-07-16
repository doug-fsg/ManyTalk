# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPolicy, type: :policy do
  subject { described_class.new(user_context, activity) }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:activity) do
    create(:activity, account: account, user: agent, assignee: agent)
  end

  def user_context(user)
    account_user = AccountUser.find_by(user: user, account: account)
    { user: user, account: account, account_user: account_user }
  end

  describe 'Scope' do
    let!(:admin_activity) { create(:activity, account: account, user: admin, assignee: admin) }
    let!(:agent_activity) { create(:activity, account: account, user: agent, assignee: agent) }
    let!(:other_activity) do
      create(:activity, account: account, user: other_agent, assignee: other_agent)
    end

    it 'returns all activities for administrators' do
      scope = described_class::Scope.new(user_context(admin), Activity.all).resolve
      expect(scope).to contain_exactly(admin_activity, agent_activity, other_activity)
    end

    it 'returns only owned or assigned activities for agents' do
      scope = described_class::Scope.new(user_context(agent), Activity.all).resolve
      expect(scope).to contain_exactly(agent_activity)
    end
  end

  describe '#update?' do
    it 'allows administrator' do
      expect(described_class.new(user_context(admin), activity).update?).to be true
    end

    it 'allows assignee' do
      expect(described_class.new(user_context(agent), activity).update?).to be true
    end

    it 'denies unrelated agent' do
      expect(described_class.new(user_context(other_agent), activity).update?).to be false
    end
  end
end
