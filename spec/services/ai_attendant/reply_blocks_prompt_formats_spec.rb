# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::ReplyBlocks, 'formatos de prompt/resposta do usuário' do
  let(:account) { create(:account) }
  let(:config) { create(:ai_attendant_config, account: account) }
  let(:token) { '{{anexo:5895c30be7bce75cc5318a08}}' }

  before do
    config.reference_files.attach(
      io: File.open(Rails.root.join('spec/assets/avatar.png')),
      filename: '5895c30be7bce75cc5318a08.jpeg',
      content_type: 'image/jpeg'
    )
  end

  def block_types(text)
    described_class.parse(text, config).map { |block| block[:type] }
  end

  def block_contents(text)
    described_class.parse(text, config).map { |block| block[:content].to_s }
  end

  it 'passo 1: saudação inline + linha seguinte pedindo o nome (\\n simples)' do
    text = <<~MSG.strip
      de uma saudacao longa, e envie isso #{token}
      depois pergunte o nome
    MSG

    expect(block_types(text)).to eq(%i[text attachment text])
    expect(block_contents(text).first).to include('saudacao longa')
    expect(block_contents(text).last).to include('depois pergunte o nome')
  end

  it 'passo 1: parágrafos separados por linha em branco (\\n\\n)' do
    text = <<~MSG.strip
      de uma saudacao longa, e envie isso #{token}

      depois pergunte o nome
    MSG

    expect(block_types(text)).to eq(%i[text attachment text])
  end

  it 'saudação, anexo em linha dedicada e pergunta final' do
    text = <<~MSG.strip
      Boa tarde! Tudo bem?

      #{token}

      Qual é o seu nome?
    MSG

    expect(block_types(text)).to eq(%i[text attachment text])
  end

  it 'saudação e anexo na mesma linha com pergunta na linha seguinte' do
    text = "Boa tarde! #{token}\nQual é o seu nome?"

    expect(block_types(text)).to eq(%i[text attachment text])
  end

  it 'bloco só com a variável' do
    expect(block_types(token)).to eq([:attachment])
  end

  it 'texto antes e depois do token na mesma linha' do
    text = "Segue o material #{token} conforme combinado"

    expect(block_types(text)).to eq(%i[text attachment text])
    expect(block_contents(text).reject(&:blank?)).to eq(
      ['Segue o material', 'conforme combinado']
    )
  end

  it 'dois tokens válidos no mesmo bloco' do
    text = "Primeiro #{token} e de novo #{token}"

    expect(block_types(text)).to eq(%i[text attachment text attachment])
  end

  it 'token com extensão do arquivo no nome (erro comum do usuário)' do
    text = '{{anexo:5895c30be7bce75cc5318a08.jpeg}}'

    expect(block_types(text)).to eq([:attachment])
  end

  it 'token desconhecido permanece texto' do
    text = "Olá {{anexo:arquivo-inexistente}}"

    expect(block_types(text)).to eq([:text])
    expect(block_contents(text).first).to include('arquivo-inexistente')
  end

  it 'resposta sem variável (modelo ignorou o anexo) não inventa attachment' do
    text = <<~MSG.strip
      Olá! Seja bem-vindo à nossa loja.

      Como posso te chamar?
    MSG

    expect(block_types(text)).to eq(%i[text text])
  end

  it 'hífen vs underscore no token (img_5612 / img-5612)' do
    config.reference_files.purge
    config.reference_files.attach(
      io: File.open(Rails.root.join('spec/assets/avatar.png')),
      filename: 'IMG_5612.jpg',
      content_type: 'image/jpeg'
    )

    text = 'Segue {{anexo:img-5612}}'

    expect(block_types(text)).to eq(%i[text attachment])
  end

  it 'múltiplos parágrafos de texto sem token ficam em um único bloco' do
    text = <<~MSG.strip
      Linha um do poema
      Linha dois do poema
    MSG

    expect(block_types(text)).to eq([:text])
    expect(block_contents(text).join).to include('Linha um do poema')
    expect(block_contents(text).join).to include('Linha dois do poema')
  end
end
