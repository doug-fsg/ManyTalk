require 'rails_helper'

RSpec.describe Whatsapp::TemplateProcessorService do
  subject(:processed_components) do
    described_class.new(channel: channel, template_params: template_params).call.last
  end

  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      message_templates: [template]
    )
  end

  context 'with a positional text header' do
    let(:template) do
      {
        'name' => 'positional_header',
        'namespace' => 'ns',
        'language' => 'en_US',
        'status' => 'approved',
        'parameter_format' => 'POSITIONAL',
        'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Welcome {{1}}' }]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => { 'header' => { '1' => 'Jane' } }
      }
    end

    it 'builds a positional text parameter' do
      expect(processed_components).to eq([
                                           {
                                             type: 'header',
                                             parameters: [{ type: 'text', text: 'Jane' }]
                                           }
                                         ])
    end
  end

  context 'with a named text header' do
    let(:template) do
      {
        'name' => 'named_header',
        'namespace' => 'ns',
        'language' => 'en_US',
        'status' => 'approved',
        'parameter_format' => 'NAMED',
        'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => "Welcome {{#{parameter_name}}}" }]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => { 'header' => { parameter_name => 'Jane' } }
      }
    end

    %w[customer_name media_type media_name].each do |name|
      context "when the parameter is #{name}" do
        let(:parameter_name) { name }

        it 'preserves the parameter name' do
          expect(processed_components).to eq([
                                               {
                                                 type: 'header',
                                                 parameters: [{ type: 'text', parameter_name: parameter_name, text: 'Jane' }]
                                               }
                                             ])
        end
      end
    end
  end

  context 'with positional body parameters' do
    let(:template) do
      {
        'name' => 'positional_body',
        'namespace' => 'ns',
        'language' => 'en_US',
        'status' => 'approved',
        'parameter_format' => 'POSITIONAL',
        'components' => [{ 'type' => 'BODY', 'text' => '{{1}} / {{2}}' }]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => {
          'body' => {
            '2' => 'Bob',
            '1' => 'Alice'
          }
        }
      }
    end

    it 'orders parameters by their positional key' do
      expect(processed_components).to eq([
                                           {
                                             type: 'body',
                                             parameters: [
                                               { type: 'text', text: 'Alice' },
                                               { type: 'text', text: 'Bob' }
                                             ]
                                           }
                                         ])
    end
  end

  context 'with named body parameters' do
    let(:template) do
      {
        'name' => 'named_body',
        'namespace' => 'ns',
        'language' => 'en_US',
        'status' => 'approved',
        'parameter_format' => 'NAMED',
        'components' => [{ 'type' => 'BODY', 'text' => 'Hi {{first_name}}, order {{order_id}}' }]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => {
          'body' => {
            'order_id' => 'ABC-99',
            'first_name' => 'Maria'
          }
        }
      }
    end

    it 'preserves named parameter keys in body components' do
      expect(processed_components).to eq([
                                           {
                                             type: 'body',
                                             parameters: [
                                               { type: 'text', parameter_name: 'order_id', text: 'ABC-99' },
                                               { type: 'text', parameter_name: 'first_name', text: 'Maria' }
                                             ]
                                           }
                                         ])
    end
  end

  context 'with a media header' do
    let(:template) do
      {
        'name' => 'document_header',
        'namespace' => 'ns',
        'language' => 'en_US',
        'status' => 'approved',
        'parameter_format' => 'POSITIONAL',
        'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' }]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => {
          'header' => {
            'media_url' => 'https://example.com/report.pdf',
            'media_type' => 'document',
            'media_name' => 'report.pdf'
          }
        }
      }
    end

    it 'uses media metadata to build the attachment parameter' do
      expect(processed_components).to eq([
                                           {
                                             type: 'header',
                                             parameters: [
                                               {
                                                 type: 'document',
                                                 document: {
                                                   link: 'https://example.com/report.pdf',
                                                   filename: 'report.pdf'
                                                 }
                                               }
                                             ]
                                           }
                                         ])
    end
  end

  context 'when media_type is omitted' do
    let(:template) do
      {
        'name' => 'promo_image',
        'namespace' => 'ns',
        'language' => 'pt_BR',
        'status' => 'approved',
        'components' => [
          { 'type' => 'HEADER', 'format' => 'IMAGE' },
          { 'type' => 'BODY', 'text' => 'Olá {{1}}' }
        ]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => {
          'body' => { '1' => 'Maria' },
          'header' => { 'media_url' => 'https://example.com/banner.jpg' }
        }
      }
    end

    it 'infers IMAGE media_type from the template definition' do
      expect(processed_components.find { |c| c[:type] == 'header' }[:parameters]).to eq(
        [
          {
            type: 'image',
            image: { link: 'https://example.com/banner.jpg' }
          }
        ]
      )
    end
  end

  context 'with legacy flat params' do
    let(:template) do
      {
        'name' => 'order_update',
        'namespace' => 'ns',
        'language' => 'pt_BR',
        'status' => 'approved',
        'components' => [{ 'type' => 'BODY', 'text' => 'Olá {{1}}, pedido {{2}}' }]
      }
    end
    let(:template_params) do
      {
        'name' => 'order_update',
        'namespace' => 'ns',
        'language' => 'pt_BR',
        'processed_params' => { '1' => 'Maria', '2' => 'ABC-99' }
      }
    end

    it 'converts legacy flat params to body components' do
      expect(processed_components).to eq([
                                           {
                                             type: 'body',
                                             parameters: [
                                               { type: 'text', text: 'Maria' },
                                               { type: 'text', text: 'ABC-99' }
                                             ]
                                           }
                                         ])
    end
  end
end
