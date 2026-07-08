require 'rails_helper'

RSpec.describe Whatsapp::TemplateProcessorService do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      message_templates: [
        {
          'name' => 'order_update',
          'namespace' => 'ns',
          'language' => 'pt_BR',
          'status' => 'approved',
          'components' => [{ 'type' => 'BODY', 'text' => 'Olá {{1}}, pedido {{2}}' }]
        }
      ]
    )
  end

  it 'converts legacy flat params to body components' do
    template_params = {
      'name' => 'order_update',
      'namespace' => 'ns',
      'language' => 'pt_BR',
      'processed_params' => { '1' => 'Maria', '2' => 'ABC-99' }
    }

    _name, _namespace, _lang, components = described_class.new(
      channel: channel,
      template_params: template_params
    ).call

    expect(components).to eq([
                               {
                                 type: 'body',
                                 parameters: [
                                   { type: 'text', text: 'Maria' },
                                   { type: 'text', text: 'ABC-99' }
                                 ]
                               }
                             ])
  end

  it 'builds header and button components from enhanced params' do
    channel.update!(message_templates: [
                      {
                        'name' => 'promo_doc',
                        'namespace' => 'ns',
                        'language' => 'pt_BR',
                        'status' => 'approved',
                        'components' => [
                          { 'type' => 'HEADER', 'format' => 'DOCUMENT' },
                          { 'type' => 'BODY', 'text' => 'Confira {{1}}' },
                          {
                            'type' => 'BUTTONS',
                            'buttons' => [{ 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x.com/{{1}}' }]
                          }
                        ]
                      }
                    ])

    template_params = {
      'name' => 'promo_doc',
      'namespace' => 'ns',
      'language' => 'pt_BR',
      'processed_params' => {
        'body' => { '1' => 'oferta' },
        'header' => {
          'media_url' => 'https://example.com/doc.pdf',
          'media_type' => 'document',
          'media_name' => 'doc.pdf'
        },
        'buttons' => [{ 'type' => 'url', 'parameter' => 'token123' }]
      }
    }

    _name, _namespace, _lang, components = described_class.new(
      channel: channel,
      template_params: template_params
    ).call

    expect(components.find { |c| c[:type] == 'header' }[:parameters].first[:type]).to eq('document')
    expect(components.find { |c| c[:type] == 'body' }[:parameters].first[:text]).to eq('oferta')
    expect(components.find { |c| c[:type] == 'button' }[:sub_type]).to eq('url')
  end
end
