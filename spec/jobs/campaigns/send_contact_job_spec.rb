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
                    setex: true,
                    del: true,
                    zrangebyscore: [],
                    lrange: [],
                    ltrim: true)
  end

  before do
    allow($alfred).to receive(:with).and_yield(redis_double)
    allow(ActionCableBroadcastJob).to receive(:perform_later)
    stub_request(:any, /n8n.example.com/).to_return(status: 200, body: "")
    allow_any_instance_of(described_class).to receive(:sleep)
    
    # Global redis mocks to avoid "paused_or_stopped_count" false positives
    allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:stop_requested").and_return(nil)
    allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:pause_requested").and_return(nil)
  end

  describe '#perform' do
    context 'with a valid contact hash from spreadsheet' do
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990001', 'nome' => 'João' } }

      it 'normalizes local 11-digit numbers without inventing a ninth digit' do
        raw_contact = { 'type' => 'Contact', 'id' => '11999999999', 'nome' => 'Test' }
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
        expect(ActionCableBroadcastJob).to have_received(:perform_later).at_least(:once)
      end
    end

    context 'when contact has already been sent for this campaign' do
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990002', 'nome' => 'Maria' } }

      before do
        contact = create(:contact, account: account, phone_number: '+5511999990002')
        contact_inbox = create(:contact_inbox, contact: contact, inbox: api_inbox, source_id: '5511999990002')
        create(:conversation, account: account, contact: contact, inbox: api_inbox, contact_inbox: contact_inbox, campaign_id: campaign.id)
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

    context 'when a Brazilian phone variant already exists' do
      let(:contact_data) { { 'type' => 'Contact', 'id' => '555599067484', 'nome' => 'RS' } }

      before do
        create(:contact, account: account, phone_number: '+5555999067484', name: 'Existing')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:total_count").and_return('10')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:processed_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:last_broadcast_at").and_return('0')
      end

      it 'reuses the existing contact instead of creating a duplicate' do
        expect {
          described_class.perform_now(campaign.id, contact_data)
        }.not_to change(Contact, :count)
      end
    end

    context 'when the contact already has an open assigned conversation' do
      let(:agent) { create(:user, account: account) }
      let(:contact_data) { { 'type' => 'Contact', 'id' => '5511999990005', 'nome' => 'Lead' } }
      let!(:contact) { create(:contact, account: account, phone_number: '+5511999990005') }
      let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: api_inbox, source_id: '5511999990005') }
      let!(:open_conversation) do
        create(:conversation, account: account, inbox: api_inbox, contact: contact,
                              contact_inbox: contact_inbox, assignee: agent, status: :open)
      end

      before do
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:total_count").and_return('10')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:processed_count").and_return('1')
        allow(redis_double).to receive(:get).with("campaign:#{campaign.id}:last_broadcast_at").and_return('0')
      end

      it 'sends on the open conversation and does not snooze it' do
        expect {
          described_class.perform_now(campaign.id, contact_data)
        }.to change(Message, :count).by(1)
          .and not_change(Conversation, :count)

        expect(open_conversation.reload.status).to eq('open')
        expect(open_conversation.assignee_id).to eq(agent.id)
      end
    end
  end
end
