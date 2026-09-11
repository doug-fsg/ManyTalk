# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomRole do
  let(:account) { create(:account) }

  it 'requires at least one permission' do
    role = build(:custom_role, account: account, permissions: [])

    expect(role).not_to be_valid
    expect(role.errors[:permissions]).to be_present
  end

  it 'rejects unsupported permissions' do
    role = build(:custom_role, account: account, permissions: ['not_a_permission'])

    expect(role).not_to be_valid
    expect(role.errors[:permissions]).to be_present
  end
end
