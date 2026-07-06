# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountForms::BrandingSanitizer do
  describe '.call' do
    it 'fills defaults for empty branding' do
      result = described_class.call({})
      expect(result['background_color']).to eq('#ffffff')
      expect(result['page_background_color']).to eq('#f8fafc')
      expect(result['text_color']).to eq('#0f172a')
      expect(result['logo_alignment']).to eq('center')
      expect(result['logo_expand']).to eq(false)
      expect(result['primary_color']).to eq('#1f93ff')
    end


    it 'drops unknown keys' do
      result = described_class.call('foo' => 'bar', 'primary_color' => '#112233')
      expect(result).not_to have_key('foo')
      expect(result['primary_color']).to eq('#112233')
    end

    it 'coerces invalid hex to default' do
      result = described_class.call(
        'background_color' => 'red;}',
        'text_color' => '#fff; background:url(x)'
      )
      expect(result['background_color']).to eq('#ffffff')
      expect(result['text_color']).to eq('#0f172a')
    end

    it 'normalizes hex case' do
      result = described_class.call('primary_color' => '#ABC')
      expect(result['primary_color']).to eq('#abc')
    end

    it 'normalizes logo_alignment' do
      expect(described_class.call('logo_alignment' => 'left')['logo_alignment']).to eq('left')
      expect(described_class.call('logo_alignment' => 'middle')['logo_alignment']).to eq('center')
    end

    it 'coerces logo_expand to boolean' do
      expect(described_class.call('logo_expand' => 'true')['logo_expand']).to eq(true)
      expect(described_class.call('logo_expand' => 'false')['logo_expand']).to eq(false)
      expect(described_class.call('logo_expand' => 1)['logo_expand']).to eq(true)
    end

    it 'blocks dangerous logo_url schemes' do
      result = described_class.call('logo_url' => 'javascript:alert(1)')
      expect(result['logo_url']).to eq('')
    end

    it 'allows http(s) and relative logo urls' do
      expect(described_class.call('logo_url' => 'https://cdn.example/logo.png')['logo_url'])
        .to eq('https://cdn.example/logo.png')
      expect(described_class.call('logo_url' => '/rails/active_storage/x')['logo_url'])
        .to eq('/rails/active_storage/x')
    end

    it 'strips html from header fields' do
      result = described_class.call('header_title' => '<b>Hello</b>')
      expect(result['header_title']).to eq('Hello')
    end
  end
end
