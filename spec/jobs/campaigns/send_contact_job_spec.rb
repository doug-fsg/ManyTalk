require 'rails_helper'

RSpec.describe Campaigns::SendContactJob do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel_api) { create(:channel_api, webhook_url: 'https://n8n.example.com/webhook') }
  let(:api_inbox) { create(:inbox, account: account, channel: channel_api) }
  let(:campaign) do
    create(:campaign,
           account: account,
           inbox: api_inbox,
           campaign_type: :one_off,
           campaign_status: :processing,
           message: 'Olá {nome}!',
           sender: admin,
           trigger_rules: {})
  end

  let(:redis_double) do
    instance_double(Redis,
                    incr: 1,
                    get: '0',
                    rpush: true,
                    set: true,
                    del: true,
                    lrange: [],
                    ltrim: true)
  end

  before do
    allow($alfred).to receive(:with).and_yield(redis_double)
    allow(ActionCableBroadcastJob).to receive(:perform_later)
  end

  describe '#perform' do
    context 'with a valid contact hash from spreadsheet' do
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990001', 'nome' => 'João' } }

      it 'normalizes raw 10-digit number with DDD < 31' do
        raw_contact = { 'type' => 'Contact', 'id' => '1199999999', 'nome' => 'Test' }
        expect {
          described_class.perform_now(campaign.id, raw_contact)
        }.to change(Contact, :count).by(1)
        expect(Contact.last.phone_number).to eq('+5511999999999')
      end

      before do
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:total_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:processed_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:sent_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:failed_count").and_return('0')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:stop_requested").and_return(nil)
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:pause_requested").and_return(nil)
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:last_broadcast_at").and_return('0')
      end

      it 'creates contact, conversation and message' do
        expect {
          described_class.perform_now(campaign.id, contact_data)
        }.to change(Contact, :count).by(1)
          .and change(Conversation, :count).by(1)
          .and change(Message, :count).by(1)
      end

      it 'marks campaign as completed when processed_count >= total_count' do
        described_class.perform_now(campaign.id, contact_data)
        expect(campaign.reload.campaign_status).to eq('completed')
      end

      it 'broadcasts progress' do
        described_class.perform_now(campaign.id, contact_data)
        expect(ActionCableBroadcastJob).to have_received(:perform_later)
      end
    end

    context 'when contact has already been sent for this campaign' do
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990002', 'nome' => 'Maria' } }

      before do
        contact = create(:contact, account: account, phone_number: '+5511999990002')
        contact_inbox = create(:contact_inbox, contact: contact, inbox: api_inbox, source_id: '5511999990002')
        create(:conversation, account: account, contact: contact, inbox: api_inbox, contact_inbox: contact_inbox, campaign_id: campaign.id)
        allow(redis_double).to receive(:get).and_return('0')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:total_count").and_return('10')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:processed_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:last_broadcast_at").and_return('0')
      end

      it 'skips sending and tracks as success' do
        expect {
          described_class.perform_now(campaign.id, contact_data)
        }.not_to change(Message, :count)

        expect(redis_double).to have_received(:incr).with("campaign:#{campaign.id}:sent_count")
      end
    end

    context 'with macro_id in trigger_rules' do
      let(:macro) { create(:macro, account: account) }
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990003', 'nome' => 'Pedro' } }

      before do
        campaign.update!(trigger_rules: { 'macro_id' => macro.id.to_s })
        allow(redis_double).to receive(:get).and_return('0')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:total_count").and_return('10')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:processed_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:last_broadcast_at").and_return('0')
      end

      it 'enqueues MacrosExecutionJob' do
        expect(MacrosExecutionJob).to receive(:perform_later)
        described_class.perform_now(campaign.id, contact_data)
      end
    end

    context 'when campaign is stopped or paused' do
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990004', 'nome' => 'Ana' } }

      before do
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:stop_requested").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:pause_requested").and_return(nil)
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:total_count").and_return('10')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:processed_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:last_broadcast_at").and_return('0')
      end

      it 'skips sending and increments paused_or_stopped_count' do
        expect {
          described_class.perform_now(campaign.id, contact_data)
        }.not_to change(Message, :count)

        expect(redis_double).to have_received(:incr).with("campaign:#{campaign.id}:paused_or_stopped_count")
      end
    end

    context 'when campaign is not found' do
      it 'returns without error' do
        expect { described_class.perform_now(99_999, {}) }.not_to raise_error
      end
    end
  end
end
