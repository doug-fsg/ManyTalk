require 'rails_helper'

describe Whatsapp::IncomingMessageServiceHelpers do
  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  # Lightweight host to exercise BR waid matching without the full webhook pipeline.
  let(:helper_host) do
    Class.new do
      include Whatsapp::IncomingMessageServiceHelpers
      attr_reader :inbox

      def initialize(inbox)
        @inbox = inbox
      end
    end
  end

  let!(:whatsapp_channel) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox }
  let(:helper) { helper_host.new(inbox) }

  describe '#processed_waid' do
    let(:with_nine) { '5541988887777' }
    let(:without_nine) { '554188887777' }

    it 'returns the incoming waid when no contact inbox exists' do
      expect(helper.processed_waid(with_nine)).to eq(with_nine)
      expect(helper.processed_waid(without_nine)).to eq(without_nine)
    end

    it 'reuses existing contact inbox when incoming has 9 and stored source_id does not' do
      create(:contact_inbox, inbox: inbox, source_id: without_nine)

      expect(helper.processed_waid(with_nine)).to eq(without_nine)
    end

    it 'reuses existing contact inbox when incoming lacks 9 and stored source_id has 9' do
      create(:contact_inbox, inbox: inbox, source_id: with_nine)

      expect(helper.processed_waid(without_nine)).to eq(with_nine)
    end

    it 'prefers exact source_id match when both variants exist' do
      create(:contact_inbox, inbox: inbox, source_id: without_nine)
      create(:contact_inbox, inbox: inbox, source_id: with_nine)

      expect(helper.processed_waid(with_nine)).to eq(with_nine)
      expect(helper.processed_waid(without_nine)).to eq(without_nine)
    end

    it 'does not alter non-brazilian waids' do
      expect(helper.processed_waid('919746334593')).to eq('919746334593')
    end
  end
end
