# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ReplyBlocks do
  let(:account) { create(:account) }
  let(:config) { create(:ai_attendant_config, account: account) }

  before do
    config.reference_files.attach(
      io: File.open(Rails.root.join('spec/assets/avatar.png')),
      filename: 'catalogo.png',
      content_type: 'image/png'
    )
  end

  describe '.parse' do
    it 'keeps ordinary text blocks' do
      blocks = described_class.parse('Olá', config)

      expect(blocks).to eq([{ type: :text, content: 'Olá' }])
    end

    it 'maps a file variable block to the attached blob' do
      blocks = described_class.parse("Segue o catálogo\n\n{{anexo:catalogo}}", config)

      expect(blocks.first).to eq(type: :text, content: 'Segue o catálogo')
      expect(blocks.last[:type]).to eq(:attachment)
      expect(blocks.last[:filename]).to eq('catalogo.png')
      expect(blocks.last[:file_type]).to eq('image')
      expect(blocks.last[:token]).to eq('{{anexo:catalogo}}')
      expect(blocks.last[:file].blob).to eq(config.reference_files.first.blob)
    end

    it 'maps a camera filename token to an attachment' do
      extra = create(:ai_attendant_config, account: account)
      extra.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'IMG_5612.jpg',
        content_type: 'image/jpeg'
      )

      blocks = described_class.parse('{{anexo:img_5612}}', extra)

      expect(blocks).to contain_exactly(
        hash_including(type: :attachment, token: '{{anexo:img_5612}}', filename: 'IMG_5612.jpg')
      )
    end

    it 'splits inline text and a single file variable into text plus attachment' do
      blocks = described_class.parse('Olá! {{anexo:catalogo}}', config)

      expect(blocks.first).to eq(type: :text, content: 'Olá!')
      expect(blocks.last).to include(
        type: :attachment,
        token: '{{anexo:catalogo}}',
        filename: 'catalogo.png'
      )
    end

    it 'splits a behavior-step style greeting with inline token' do
      extra = create(:ai_attendant_config, account: account)
      extra.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: 'IMG_5612.jpg',
        content_type: 'image/jpeg'
      )

      blocks = described_class.parse(
        'de uma saudacao , e envie isso {{anexo:img_5612}}',
        extra
      )

      expect(blocks.first[:type]).to eq(:text)
      expect(blocks.first[:content]).to include('saudacao')
      expect(blocks.last).to include(
        type: :attachment,
        token: '{{anexo:img_5612}}',
        filename: 'IMG_5612.jpg'
      )
    end

    it 'keeps unknown inline tokens as plain text' do
      blocks = described_class.parse('Olá {{anexo:inexistente}}', config)

      expect(blocks).to eq([{ type: :text, content: 'Olá {{anexo:inexistente}}' }])
    end

    it 'sends two attachments when the same variable appears twice' do
      blocks = described_class.parse('{{anexo:catalogo}} e {{anexo:catalogo}}', config)

      expect(blocks.map { |block| block[:type] }).to eq(
        %i[attachment text attachment]
      )
    end
  end

  describe '.as_json' do
    it 'serializes attachment blocks for the sandbox test' do
      payload = described_class.as_json('{{anexo:catalogo}}', config)

      expect(payload).to contain_exactly(
        hash_including(
          'type' => 'attachment',
          'token' => '{{anexo:catalogo}}',
          'filename' => 'catalogo.png',
          'file_type' => 'image'
        )
      )
    end
  end
end
