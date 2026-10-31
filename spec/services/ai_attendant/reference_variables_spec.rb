# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ReferenceVariables do
  describe '.entries' do
    it 'builds unique {{anexo:name}} tokens from filenames' do
      first = double(filename: 'Catálogo.pdf')
      second = double(filename: 'catalogo.png')

      entries = described_class.entries([first, second])

      expect(entries.map { |entry| entry[:token] }).to eq(
        %w[{{anexo:catalogo}} {{anexo:catalogo-2}}]
      )
    end
  end

  describe '.lookup_file' do
    it 'finds the file by exact variable token' do
      file = double(filename: 'precos.xlsx')

      expect(described_class.lookup_file([file], '{{anexo:precos}}')).to eq(file)
      expect(described_class.lookup_file([file], 'veja {{anexo:precos}}')).to be_nil
    end

    it 'matches camera filenames that keep an underscore' do
      file = double(filename: 'IMG_5612.jpg')

      expect(described_class.entries([file]).first[:token]).to eq('{{anexo:img_5612}}')
      expect(described_class.lookup_file([file], '{{anexo:img_5612}}')).to eq(file)
      expect(described_class.lookup_file([file], '{{anexo:img-5612}}')).to eq(file)
    end
  end

  describe '.split_message' do
    it 'splits text, attachment and trailing text in order' do
      file = create_reference_file('5895c30be7bce75cc5318a08.jpeg')

      segments = described_class.split_message(
        'saudacao {{anexo:5895c30be7bce75cc5318a08}} depois nome',
        [file]
      )

      expect(segments.map { |s| s[:type] }).to eq(%i[text attachment text])
      expect(segments[0][:content]).to eq('saudacao')
      expect(segments[1][:token]).to eq('{{anexo:5895c30be7bce75cc5318a08}}')
      expect(segments[2][:content]).to eq('depois nome')
    end

    it 'resolves keys with file extension suffix' do
      file = create_reference_file('5895c30be7bce75cc5318a08.jpeg')

      segments = described_class.split_message('{{anexo:5895c30be7bce75cc5318a08.jpeg}}', [file])

      expect(segments.size).to eq(1)
      expect(segments.first[:type]).to eq(:attachment)
      expect(segments.first[:file].blob).to eq(file.blob)
    end

    def create_reference_file(name)
      config = create(:ai_attendant_config)
      config.reference_files.attach(
        io: File.open(Rails.root.join('spec/assets/avatar.png')),
        filename: name,
        content_type: 'image/jpeg'
      )
      config.reference_files.first
    end
  end

  describe '.inline_attachment' do
    it 'returns text and file when a single token appears with surrounding copy' do
      file = double(filename: 'precos.xlsx')

      parts = described_class.inline_attachment([file], 'veja {{anexo:precos}}')

      expect(parts).to eq(
        text: 'veja',
        token: '{{anexo:precos}}',
        file: file
      )
    end

    it 'returns nil for an exact token-only block' do
      file = double(filename: 'precos.xlsx')

      expect(described_class.inline_attachment([file], '{{anexo:precos}}')).to be_nil
    end
  end

  describe '.replace_legacy_tokens' do
    it 'replaces sequential [REFERENCIA] with named variables' do
      file = double(filename: 'menu.pdf')

      text = described_class.replace_legacy_tokens('Envie [REFERENCIA]', [file])

      expect(text).to eq('Envie {{anexo:menu}}')
    end
  end
end
