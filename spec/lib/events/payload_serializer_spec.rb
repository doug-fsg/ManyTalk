# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::PayloadSerializer do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }

  describe '.dump' do
    it 'serializes ActiveRecord models to id hashes' do
      payload = described_class.dump(message: message, note: 'hello')

      expect(payload).to eq(
        'message' => { '__ar__' => 'Message', 'id' => message.id },
        'note' => 'hello'
      )
    end

    it 'serializes nested hashes and arrays' do
      payload = described_class.dump(
        changed_attributes: { 'status' => %w[open resolved] },
        tags: [message]
      )

      expect(payload['changed_attributes']).to eq('status' => %w[open resolved])
      expect(payload['tags']).to eq([{ '__ar__' => 'Message', 'id' => message.id }])
    end
  end

  describe '.load' do
    it 'hydrates serialized models' do
      payload = {
        'message' => { '__ar__' => 'Message', 'id' => message.id }
      }

      expect(described_class.load(payload)[:message]).to eq(message)
    end

    it 'returns nil when the record no longer exists' do
      payload = {
        'message' => { '__ar__' => 'Message', 'id' => -1 }
      }

      expect(described_class.load(payload)[:message]).to be_nil
    end
  end

  describe '.missing_primary_record?' do
    it 'detects missing message for message events' do
      data = { message: nil }

      expect(described_class.missing_primary_record?(Events::Types::MESSAGE_CREATED, data)).to be true
    end

    it 'allows events without a mapped primary record' do
      data = { account: nil }

      expect(described_class.missing_primary_record?(Events::Types::AGENT_ADDED, data)).to be false
    end
  end
end
