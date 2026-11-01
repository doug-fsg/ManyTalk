# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::Eligibility do
  describe '.call' do
    subject(:result) { described_class.call(message: message) }

    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:message) do
      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        message_type: :incoming,
        content_type: :text,
        private: false
      )
    end

    before do
      account.enable_features!('atendimento_ia_nativo')
      create(:ai_attendant_config, account: account, inbox_id: inbox.id, active: true)
    end

    it 'rejects assigned conversations with reason assigned' do
      conversation.update!(assignee: create(:user, account: account, role: :agent))

      expect(result).to eq(eligible: false, reason: 'assigned')
    end

    it 'is eligible for incoming unassigned messages when config is active and feature is on' do
      expect(result).to eq(eligible: true, reason: nil)
    end

    it 'keeps incoming image messages eligible in v1' do
      attach_file(file_type: :image, filename: 'photo.jpg', content_type: 'image/jpeg')

      expect(result).to eq(eligible: true, reason: nil)
    end

    it 'rejects activity messages' do
      message.update!(message_type: :activity)

      expect(result[:eligible]).to be(false)
    end

    it 'rejects reaction messages' do
      message.update!(content_attributes: { 'type' => 'reaction' })

      expect(result[:eligible]).to be(false)
    end

    it 'rejects sticker messages' do
      message.update!(content_type: :sticker)

      expect(result[:eligible]).to be(false)
    end

    it 'rejects WhatsApp stickers persisted as image attachments' do
      # Production ingest (Whatsapp::IncomingMessageServiceHelpers#file_content_type)
      # maps webhook type "sticker" → Attachment#file_type :image and never sets
      # Message#content_type :sticker. Graph media Content-Type is image/webp.
      attach_file(file_type: :image, filename: 'wamid-media', content_type: 'image/webp')

      expect(message.content_type).to eq('text')
      expect(message.attachments.first.file_type).to eq('image')
      expect(result).to eq(eligible: false, reason: 'unsupported_media')
    end

    it 'rejects incoming audio with reason audio_unsupported' do
      message.attachments.create!(account_id: account.id, file_type: :audio)

      expect(result).to eq(eligible: false, reason: 'audio_unsupported')
    end

    it 'rejects the conversation after handoff' do
      conversation.update!(additional_attributes: { 'ai_handoff_at' => Time.current.iso8601 })

      expect(result).to eq(eligible: false, reason: 'handoff')
    end

    it 'keeps the contact eligible when only the contact has ai_handoff_at' do
      conversation.contact.update!(custom_attributes: { 'ai_handoff_at' => Time.current.iso8601, 'idioma' => 'pt-BR' })

      expect(result).to eq(eligible: true, reason: nil)
      expect(conversation.contact.reload.custom_attributes['idioma']).to eq('pt-BR')
    end

    it 'rejects when the feature flag is off' do
      account.disable_features!('atendimento_ia_nativo')

      expect(result[:eligible]).to be(false)
    end

    it 'rejects when config is missing' do
      AiAttendantConfigInbox.delete_all
      AiAttendantConfig.delete_all

      expect(result[:eligible]).to be(false)
    end

    it 'rejects when config is inactive' do
      AiAttendantConfig.for_inbox(inbox.id).find_by!(account_id: account.id).update!(active: false)

      expect(result[:eligible]).to be(false)
    end

    it 'rejects outgoing messages' do
      message.update!(message_type: :outgoing)

      expect(result[:eligible]).to be(false)
    end

    it 'rejects private messages' do
      message.update!(private: true)

      expect(result[:eligible]).to be(false)
    end

    it 'rejects messages that are not webhook_sendable' do
      allow(message).to receive(:webhook_sendable?).and_return(false)

      expect(result[:eligible]).to be(false)
    end

    def attach_file(file_type:, filename:, content_type:)
      attachment = message.attachments.new(account_id: account.id, file_type: file_type)
      attachment.file.attach(
        io: StringIO.new('media-bytes'),
        filename: filename,
        content_type: content_type
      )
      attachment.save!
    end
  end
end
