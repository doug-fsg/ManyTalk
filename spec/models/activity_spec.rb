# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activity, type: :model do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe '#complete!' do
    it 'sets status to completed and records completed_at' do
      activity = create(:activity, account: account, user: user, assignee: user)

      freeze_time do
        activity.complete!
        expect(activity.status).to eq('completed')
        expect(activity.completed_at).to eq(Time.current)
      end
    end
  end

  describe 'status changes' do
    it 'clears completed_at when status changes away from completed' do
      activity = create(
        :activity,
        account: account,
        user: user,
        assignee: user,
        status: 'completed',
        completed_at: 1.hour.ago
      )

      activity.update!(status: 'pending')

      expect(activity.completed_at).to be_nil
    end
  end

  describe 'contact linkage' do
    it 'sets contact_id from pipeline position when missing' do
      contact = create(:contact, account: account)
      position = create(:contact_pipeline_position, contact: contact)

      activity = create(
        :activity,
        account: account,
        user: user,
        assignee: user,
        contact: nil,
        contact_pipeline_position: position
      )

      expect(activity.contact_id).to eq(contact.id)
    end
  end
end
