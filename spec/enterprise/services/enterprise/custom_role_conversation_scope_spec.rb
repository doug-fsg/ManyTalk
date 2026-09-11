# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enterprise::CustomRoleConversationScope do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }

  before { account.enable_features!('custom_roles') }

  def apply_scope(user)
    described_class.apply(account.conversations, user: user, account: account)
  end

  describe '.apply' do
    it 'returns all conversations for administrators' do
      admin = create(:user, account: account, role: :administrator)
      mine = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      other = create(:conversation, account: account, inbox: inbox, assignee: agent)

      expect(apply_scope(admin)).to contain_exactly(mine, other)
    end

    it 'returns all conversations for agents without custom roles' do
      mine = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      other = create(:conversation, account: account, inbox: inbox, assignee: agent)

      expect(apply_scope(agent)).to contain_exactly(mine, other)
    end

    it 'limits agents with conversation_participating_manage to assigned or participating conversations' do
      custom_role = create(
        :custom_role,
        account: account,
        permissions: ['conversation_participating_manage']
      )
      agent.current_account_user.update!(custom_role: custom_role)

      assigned = create(:conversation, account: account, inbox: inbox, assignee: agent)
      participating = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      create(:conversation_participant, account: account, conversation: participating, user: agent)
      hidden = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

      expect(apply_scope(agent)).to contain_exactly(assigned, participating)
      expect(apply_scope(agent)).not_to include(hidden)
    end

    it 'returns none when the custom role has no conversation permissions' do
      custom_role = create(:custom_role, account: account, permissions: ['report_manage'])
      agent.current_account_user.update!(custom_role: custom_role)
      create(:conversation, account: account, inbox: inbox, assignee: agent)

      expect(apply_scope(agent)).to be_empty
    end
  end
end
