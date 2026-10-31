# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ResponseSender do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:sender) { create(:user, account: account) }
  let(:text) { "A\n\nB" }

  describe '#perform' do
    it 'creates one message per block split by double newlines via MessageBuilder' do
      message_builder = instance_double(Messages::MessageBuilder, perform: true)

      expect(Messages::MessageBuilder).to receive(:new)
        .with(sender, conversation, { content: 'A', private: false })
        .ordered
        .and_return(message_builder)
      expect(Messages::MessageBuilder).to receive(:new)
        .with(sender, conversation, { content: 'B', private: false })
        .ordered
        .and_return(message_builder)
      expect(message_builder).to receive(:perform).twice

      count = described_class.new(conversation: conversation, sender: sender, text: text).perform

      expect(count).to eq(2)
    end

    it 'sends a reference file when the block is only the file variable' do
      config = create(:ai_attendant_config, account: account, inbox_id: conversation.inbox_id)
      config.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'catalogo.png',
        content_type: 'image/png'
      )
      blob = config.reference_files.first.blob
      message_builder = instance_double(Messages::MessageBuilder, perform: true)

      expect(Messages::MessageBuilder).to receive(:new)
        .with(sender, conversation, { content: '', private: false, attachments: [blob.signed_id] })
        .and_return(message_builder)
      expect(message_builder).to receive(:perform)

      described_class.new(
        conversation: conversation,
        sender: sender,
        text: '{{anexo:catalogo}}',
        config: config
      ).perform
    end

    it 'sends text and a reference file when the token is inline with copy' do
      config = create(:ai_attendant_config, account: account, inbox_id: conversation.inbox_id)
      config.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'catalogo.png',
        content_type: 'image/png'
      )
      blob = config.reference_files.first.blob
      text_builder = instance_double(Messages::MessageBuilder, perform: true)
      attachment_builder = instance_double(Messages::MessageBuilder, perform: true)

      expect(Messages::MessageBuilder).to receive(:new)
        .with(sender, conversation, { content: 'Olá!', private: false })
        .ordered
        .and_return(text_builder)
      expect(Messages::MessageBuilder).to receive(:new)
        .with(sender, conversation, { content: '', private: false, attachments: [blob.signed_id] })
        .ordered
        .and_return(attachment_builder)
      expect(text_builder).to receive(:perform)
      expect(attachment_builder).to receive(:perform)

      count = described_class.new(
        conversation: conversation,
        sender: sender,
        text: 'Olá! {{anexo:catalogo}}',
        config: config
      ).perform

      expect(count).to eq(2)
    end

    it 'sends a reference file as an attachment when the block is only its URL' do
      config = create(:ai_attendant_config, account: account, inbox_id: conversation.inbox_id)
      config.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'catalogo.png',
        content_type: 'image/png'
      )
      blob = config.reference_files.first.blob
      blob_url = ActiveStorageUrlHelper.url_for_attachment(config.reference_files.first)
      message_builder = instance_double(Messages::MessageBuilder, perform: true)

      expect(Messages::MessageBuilder).to receive(:new)
        .with(sender, conversation, { content: '', private: false, attachments: [blob.signed_id] })
        .and_return(message_builder)
      expect(message_builder).to receive(:perform)

      described_class.new(
        conversation: conversation,
        sender: sender,
        text: blob_url,
        config: config
      ).perform
    end
  end
end
