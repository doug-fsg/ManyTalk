require 'rails_helper'

describe Whatsapp::SendOnWhatsappService do
  template_params = {
    name: 'sample_shipping_confirmation',
    namespace: '23423423_2342423_324234234_2343224',
    language: 'en_US',
    category: 'Marketing',
    processed_params: { '1' => '3' }
  }

  describe '#perform' do
    before do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
    end

    context 'when a valid message' do
      let(:whatsapp_request) { double }
      let!(:whatsapp_channel) { create(:channel_whatsapp, sync_templates: false) }
      let!(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: '123456789') }
      let!(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }

      it 'calls channel.send_message when with in 24 hour limit' do
        # to handle the case of 24 hour window limit.
        create(:message, message_type: :incoming, content: 'test',
                         conversation: conversation)
        message = create(:message, message_type: :outgoing, content: 'test',
                                   conversation: conversation)
        allow(HTTParty).to receive(:post).and_return(whatsapp_request)
        allow(whatsapp_request).to receive(:success?).and_return(true)
        allow(whatsapp_request).to receive(:[]).with('messages').and_return([{ 'id' => '123456789' }])
        expect(HTTParty).to receive(:post).with(
          'https://waba.360dialog.io/v1/messages',
          headers: { 'D360-API-KEY' => 'test_key', 'Content-Type' => 'application/json' },
          body: { 'to' => '123456789', 'text' => { 'body' => 'test' }, 'type' => 'text' }.to_json
        )
        described_class.new(message: message).perform
        expect(message.reload.source_id).to eq('123456789')
      end

      it 'calls channel.send_template when after 24 hour limit' do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false)
        message = create(:message, message_type: :outgoing, content: 'Your package has been shipped. It will be delivered in 3 business days.',
                                   conversation: conversation)
        allow(HTTParty).to receive(:post).and_return(whatsapp_request)
        allow(whatsapp_request).to receive(:success?).and_return(true)
        allow(whatsapp_request).to receive(:[]).with('messages').and_return([{ 'id' => '123456789' }])
        expect(HTTParty).to receive(:post).with(
          'https://waba.360dialog.io/v1/messages',
          headers: { 'D360-API-KEY' => 'test_key', 'Content-Type' => 'application/json' },
          body: {
            to: '123456789',
            template: {
              name: 'sample_shipping_confirmation',
              namespace: '23423423_2342423_324234234_2343224',
              language: { 'policy': 'deterministic', 'code': 'en_US' },
              components: [{ 'type': 'body', 'parameters': [{ 'type': 'text', 'text': '3' }] }]
            },
            type: 'template'
          }.to_json
        )
        described_class.new(message: message).perform
        expect(message.reload.source_id).to eq('123456789')
      end

      it 'uses TemplateProcessorService for legacy flat processed_params without feature flag' do
        message = create(
          :message,
          additional_attributes: { template_params: template_params },
          content: 'Your package will be delivered in 3 business days.',
          conversation: conversation,
          message_type: :outgoing
        )

        expect(Whatsapp::TemplateProcessorService).to receive(:new).with(
          hash_including(
            channel: whatsapp_channel,
            message: message
          )
        ).and_call_original

        allow(HTTParty).to receive(:post).and_return(whatsapp_request)
        allow(whatsapp_request).to receive(:success?).and_return(true)
        allow(whatsapp_request).to receive(:[]).with('messages').and_return([{ 'id' => '123456789' }])
        expect(HTTParty).to receive(:post).with(
          'https://waba.360dialog.io/v1/messages',
          headers: { 'D360-API-KEY' => 'test_key', 'Content-Type' => 'application/json' },
          body: {
            to: '123456789',
            template: {
              name: 'sample_shipping_confirmation',
              namespace: '23423423_2342423_324234234_2343224',
              language: { 'policy': 'deterministic', 'code': 'en_US' },
              components: [{ 'type': 'body', 'parameters': [{ 'type': 'text', 'text': '3' }] }]
            },
            type: 'template'
          }.to_json
        )

        described_class.new(message: message).perform
        expect(message.reload.source_id).to eq('123456789')
      end

      it 'interpolates liquid variables in template processed params before sending' do
        conversation.contact.update!(name: 'Maria Silva')
        liquid_template_params = template_params.merge(
          processed_params: { '1' => 'Olá {{contact.last_name}}' }
        )
        message = create(
          :message,
          additional_attributes: { template_params: liquid_template_params },
          content: 'Your package will be delivered in 3 business days.',
          conversation: conversation,
          message_type: :outgoing
        )
        allow(HTTParty).to receive(:post).and_return(whatsapp_request)
        allow(whatsapp_request).to receive(:success?).and_return(true)
        allow(whatsapp_request).to receive(:[]).with('messages').and_return([{ 'id' => '123456789' }])
        expect(HTTParty).to receive(:post).with(
          'https://waba.360dialog.io/v1/messages',
          headers: { 'D360-API-KEY' => 'test_key', 'Content-Type' => 'application/json' },
          body: {
            to: '123456789',
            template: {
              name: 'sample_shipping_confirmation',
              namespace: '23423423_2342423_324234234_2343224',
              language: { 'policy': 'deterministic', 'code': 'en_US' },
              components: [{ 'type': 'body', 'parameters': [{ 'type': 'text', 'text': 'Olá Silva' }] }]
            },
            type: 'template'
          }.to_json
        )
        described_class.new(message: message).perform
        expect(message.reload.source_id).to eq('123456789')
      end

      it 'calls channel.send_template when template has regexp characters' do
        allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false)
        message = create(
          :message,
          message_type: :outgoing,
          content: 'عميلنا العزيز الرجاء الرد على هذه الرسالة بكلمة *نعم* للرد على إستفساركم من قبل خدمة العملاء.',
          conversation: conversation
        )
        allow(HTTParty).to receive(:post).and_return(whatsapp_request)
        allow(whatsapp_request).to receive(:success?).and_return(true)
        allow(whatsapp_request).to receive(:[]).with('messages').and_return([{ 'id' => '123456789' }])
        expect(HTTParty).to receive(:post).with(
          'https://waba.360dialog.io/v1/messages',
          headers: { 'D360-API-KEY' => 'test_key', 'Content-Type' => 'application/json' },
          body: {
            to: '123456789',
            template: {
              name: 'customer_yes_no',
              namespace: '2342384942_32423423_23423fdsdaf23',
              language: { 'policy': 'deterministic', 'code': 'ar' },
              components: [{ 'type': 'body', 'parameters': [] }]
            },
            type: 'template'
          }.to_json
        )
        described_class.new(message: message).perform
        expect(message.reload.source_id).to eq('123456789')
      end
    end

    context 'when sending media header templates via whatsapp cloud' do
      let!(:whatsapp_channel) do
        create(
          :channel_whatsapp,
          provider: 'whatsapp_cloud',
          sync_templates: false,
          validate_provider_config: false,
          message_templates: [
            {
              'name' => 'promo_doc',
              'status' => 'approved',
              'category' => 'MARKETING',
              'language' => 'pt_BR',
              'namespace' => 'ns',
              'components' => [
                { 'type' => 'HEADER', 'format' => 'DOCUMENT' },
                { 'type' => 'BODY', 'text' => 'Confira {{1}}' }
              ]
            }
          ]
        )
      end
      let!(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: '5511999999999') }
      let!(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }

      it 'sends header document component from enhanced processed_params without feature flag' do
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
            }
          }
        }
        message = create(
          :message,
          additional_attributes: { template_params: template_params },
          content: 'Confira oferta',
          conversation: conversation,
          message_type: :outgoing
        )

        stub_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
          .to_return(
            status: 200,
            body: { messages: [{ id: 'wamid.media123' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        described_class.new(message: message).perform

        expect(
          a_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
            .with { |req|
              body = JSON.parse(req.body)
              components = body.dig('template', 'components')
              header = components.find { |c| c['type'] == 'header' }
              body_component = components.find { |c| c['type'] == 'body' }

              header.dig('parameters', 0, 'type') == 'document' &&
                header.dig('parameters', 0, 'document', 'link') == 'https://example.com/doc.pdf' &&
                body_component.dig('parameters', 0, 'text') == 'oferta'
            }
        ).to have_been_made.once
        expect(message.reload.source_id).to eq('wamid.media123')
      end
    end
  end
end
