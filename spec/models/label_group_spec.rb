# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LabelGroup do
  describe 'validations' do
    it 'requires a unique name per account' do
      account = create(:account)
      create(:label_group, account: account, name: 'Status')
      duplicate = build(:label_group, account: account, name: 'Status')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'allows the same name on different accounts' do
      create(:label_group, name: 'Status')
      other = build(:label_group, name: 'Status')

      expect(other).to be_valid
    end
  end

  describe 'position' do
    it 'assigns the next position on create' do
      account = create(:account)
      first = create(:label_group, account: account)
      second = create(:label_group, account: account)

      expect(first.position).to eq(1)
      expect(second.position).to eq(2)
    end
  end

  describe 'destroy' do
    it 'nullifies associated labels' do
      account = create(:account)
      group = create(:label_group, account: account)
      label = create(:label, account: account, label_group: group)

      group.destroy!

      expect(label.reload.label_group_id).to be_nil
    end
  end
end
