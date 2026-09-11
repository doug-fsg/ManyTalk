# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom role permissions matrix' do
  let(:account) { create(:account) }

  describe 'conversation permissions' do
    let(:inbox) { create(:inbox, account: account) }
    let(:other_agent) { create(:user, account: account, role: :agent) }

    it 'conversation_manage sees every conversation in index and filter scopes' do
      user = create_custom_role_agent(account, ['conversation_manage'])
      visible = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      hidden_to_participant = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

      expect(Enterprise::CustomRoleConversationScope.apply(account.conversations, user: user, account: account))
        .to include(visible, hidden_to_participant)

      filter = Conversations::FilterService.new({ payload: [] }, user, account)
      expect(filter.perform[:conversations]).to include(visible, hidden_to_participant)
    end

    it 'conversation_unassigned_manage limits to unassigned and assigned-to-self conversations' do
      user = create_custom_role_agent(account, ['conversation_unassigned_manage'])
      mine = create(:conversation, account: account, inbox: inbox, assignee: user)
      unassigned = create(:conversation, account: account, inbox: inbox, assignee: nil)
      hidden = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

      scoped = Enterprise::CustomRoleConversationScope.apply(account.conversations, user: user, account: account)
      expect(scoped).to contain_exactly(mine, unassigned)
      expect(scoped).not_to include(hidden)
    end

    it 'conversation_participating_manage limits to assigned or participating conversations' do
      user = create_custom_role_agent(account, ['conversation_participating_manage'])
      assigned = create(:conversation, account: account, inbox: inbox, assignee: user)
      participating = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      create(:conversation_participant, account: account, conversation: participating, user: user)
      hidden = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

      scoped = Enterprise::CustomRoleConversationScope.apply(account.conversations, user: user, account: account)
      expect(scoped).to contain_exactly(assigned, participating)
      expect(scoped).not_to include(hidden)
    end

    it 'denies show when the conversation is outside the custom role scope' do
      user = create_custom_role_agent(account, ['conversation_participating_manage'])
      hidden = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      account_user = account_user_for(user)

      expect(ConversationPolicy.new(account_user, hidden).show?).to be(false)
    end
  end

  describe 'contact_manage' do
    it 'allows contact access only when granted' do
      allowed = create_custom_role_agent(account, ['contact_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])

      expect(ContactPolicy.new(account_user_for(allowed), Contact).index?).to be(true)
      expect(ContactPolicy.new(account_user_for(denied), Contact).index?).to be(false)
    end
  end

  describe 'report_manage' do
    it 'allows report access only when granted' do
      allowed = create_custom_role_agent(account, ['report_manage'])
      denied = create_custom_role_agent(account, ['contact_manage'])

      expect(ReportPolicy.new(account_user_for(allowed), :report).view?).to be(true)
      expect(ReportPolicy.new(account_user_for(denied), :report).view?).to be(false)
    end
  end

  describe 'knowledge_base_manage' do
    it 'allows help center article access only when granted' do
      allowed = create_custom_role_agent(account, ['knowledge_base_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])
      article = build(:article, account: account)

      expect(ArticlePolicy.new(account_user_for(allowed), article).index?).to be(true)
      expect(ArticlePolicy.new(account_user_for(denied), article).index?).to be(false)
    end
  end

  describe 'workflow_manage' do
    before { account.enable_features!('workflows') }

    it 'allows workflow access only when granted' do
      allowed = create_custom_role_agent(account, ['workflow_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])
      workflow = build(:workflow, account: account)

      expect(WorkflowPolicy.new(account_user_for(allowed), workflow).index?).to be(true)
      expect(WorkflowPolicy.new(account_user_for(denied), workflow).index?).to be(false)
    end
  end

  describe 'automation_manage' do
    it 'allows automation access only when granted' do
      allowed = create_custom_role_agent(account, ['automation_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])
      rule = build(:automation_rule, account: account)

      expect(AutomationRulePolicy.new(account_user_for(allowed), rule).index?).to be(true)
      expect(AutomationRulePolicy.new(account_user_for(denied), rule).index?).to be(false)
    end
  end

  describe 'form_manage' do
    before { account.enable_features!('workflows') }

    it 'allows form access only when granted' do
      allowed = create_custom_role_agent(account, ['form_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])
      form = build(:account_form, account: account)

      expect(AccountFormPolicy.new(account_user_for(allowed), form).index?).to be(true)
      expect(AccountFormPolicy.new(account_user_for(denied), form).index?).to be(false)
    end
  end

  describe 'campaign_manage' do
    it 'allows campaign access only when granted' do
      allowed = create_custom_role_agent(account, ['campaign_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])
      campaign = build(:campaign, account: account)

      expect(CampaignPolicy.new(account_user_for(allowed), campaign).index?).to be(true)
      expect(CampaignPolicy.new(account_user_for(denied), campaign).index?).to be(false)
    end
  end

  describe 'crm_manage' do
    it 'is reflected on account user permissions for downstream checks' do
      user = create_custom_role_agent(account, ['crm_manage'])

      expect(account_user_for(user).permissions).to include('crm_manage')
    end
  end

  describe 'billing_manage' do
    it 'allows stripe billing access only when granted' do
      allowed = create_custom_role_agent(account, ['billing_manage'])
      denied = create_custom_role_agent(account, ['report_manage'])
      context = ->(user) { { user: user, account: account, account_user: account_user_for(user) } }

      expect(AccountPolicy.new(context.call(allowed), account).checkout?).to be(true)
      expect(AccountPolicy.new(context.call(allowed), account).subscription?).to be(true)
      expect(AccountPolicy.new(context.call(denied), account).checkout?).to be(false)
    end
  end
end
