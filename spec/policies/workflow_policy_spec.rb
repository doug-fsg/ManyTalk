# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowPolicy do
  subject(:policy) { described_class.new(account_user, workflow) }

  let(:account) { create(:account) }
  let(:workflow) { create(:workflow, account: account) }

  context 'when agent' do
    let(:user) { create(:user, account: account) }
    let(:account_user) { AccountUser.find_by(user: user, account: account) }

    context 'when workflows feature is enabled' do
      before { account.enable_features!('workflows') }

      it { expect(policy.create?).to be true }
      it { expect(policy.update?).to be true }
      it { expect(policy.destroy?).to be true }
    end

    context 'when workflows feature is disabled' do
      before { account.disable_features!('workflows') }

      it { expect(policy.create?).to be false }
      it { expect(policy.update?).to be false }
      it { expect(policy.destroy?).to be false }
    end
  end
end
