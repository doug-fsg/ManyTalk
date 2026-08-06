# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ExternalWhatsappNotifier do
  let(:account) { create(:account) }

  describe 'WhatsApp Web (API) inbox' do
    let(:channel) do
      create(:channel_api, account: account, additional_attributes: { 'source' => 'whatsapp_web' },
                           webhook_url: 'https://bridge.example/webhook')
    end
    let(:inbox) { channel.inbox }

    it 'creates a snoozed conversation and outgoing message without opening chat' do
      expect do
        result = described_class.new(
          account: account,
          inbox_id: inbox.id,
          phone_number: '11999999999',
          message: 'Aviso do fluxo'
        ).send!

        expect(result[:success]).to be true
        expect(result[:message_id]).to be_present
        expect(result[:conversation_id]).to be_present
      end.to change(Conversation, :count).by(1)
         .and change(Message, :count).by(1)

      conversation = Conversation.last
      message = Message.last

      expect(conversation).to be_snoozed
      expect(conversation.additional_attributes['workflow_external_whatsapp']).to be true
      expect(conversation.contact.phone_number).to be_present
      expect(message).to be_outgoing
      expect(message.content).to eq('Aviso do fluxo')
      expect(message.conversation_id).to eq(conversation.id)
    end

    it 'reuses an existing snoozed external conversation' do
      first = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: 'Primeira'
      ).send!

      expect(first[:success]).to be true

      expect do
        second = described_class.new(
          account: account,
          inbox_id: inbox.id,
          phone_number: '11999999999',
          message: 'Segunda'
        ).send!

        expect(second[:success]).to be true
        expect(second[:conversation_id]).to eq(first[:conversation_id])
      end.not_to change(Conversation, :count)

      expect(Conversation.last).to be_snoozed
      expect(Message.where(conversation_id: Conversation.last.id).count).to eq(2)
    end

    it 'returns invalid_phone for blank phone' do
      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: 'abc',
        message: 'Aviso'
      ).send!

      expect(result[:success]).to be false
      expect(result[:error]).to eq('invalid_phone')
    end

    it 'returns empty_message when content is blank' do
      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: '   '
      ).send!

      expect(result[:success]).to be false
      expect(result[:error]).to eq('empty_message')
    end
  end

  describe 'unsupported inbox' do
    let(:channel) { create(:channel_api, account: account) }
    let(:inbox) { channel.inbox }

    it 'rejects non-whatsapp api inboxes' do
      result = described_class.new(
        account: account,
        inbox_id: inbox.id,
        phone_number: '11999999999',
        message: 'Aviso'
      ).send!

      expect(result[:success]).to be false
      expect(result[:error]).to eq('unsupported_inbox')
    end
  end
end
