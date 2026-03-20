require 'rails_helper'

RSpec.describe Api::OneoffApiCampaignService do
  let(:account) { create(:account) }
  let(:channel_api) { create(:channel_api, webhook_url: 'https://n8n.example.com/webhook/test') }
  let(:api_inbox) { create(:inbox, account: account, channel: channel_api) }
  let(:label) { create(:label, account: account) }
  let(:campaign) do
    create(:campaign,
           account: account,
           inbox: api_inbox,
           campaign_type: :one_off,
           campaign_status: :active,
           audience: [{ 'type' => 'Label', 'id' => label.id }],
           trigger_rules: {})
  end

  subject(:service) { described_class.new(campaign: campaign) }

  before do
    allow($alfred).to receive(:with).and_yield(instance_double(Redis, set: true, del: true))
  end

  describe '#perform' do
    context 'when inbox has no webhook_url' do
      before { channel_api.update!(webhook_url: '') }

      it 'raises an error' do
        expect { service.perform }.to raise_error(RuntimeError, /webhook URL/)
      end
    end

    context 'when campaign is already completed' do
      before { campaign.completed! }

      it 'raises an error' do
        expect { service.perform }.to raise_error(RuntimeError, /completed/)
      end
    end

    context 'when campaign is already processing' do
      before { campaign.processing! }

      it 'raises an error' do
        expect { service.perform }.to raise_error(RuntimeError, /processing/)
      end
    end

    context 'with valid campaign and label audience' do
      let!(:contact) { create(:contact, account: account, phone_number: '+5511999990001') }
      let!(:conversation) { create(:conversation, account: account, contact: contact) }

      before do
        conversation.update!(cached_label_list: label.title)
      end

      it 'marks campaign as processing and enqueues jobs' do
        expect(Campaigns::SendContactJob).to receive(:set).and_return(double(perform_later: true))
        service.perform
        expect(campaign.reload.campaign_status).to eq('processing')
      end
    end

    context 'with contact audience (planilha)' do
      let(:campaign) do
        create(:campaign,
               account: account,
               inbox: api_inbox,
               campaign_type: :one_off,
               campaign_status: :active,
               audience: [{ 'type' => 'Contact', 'id' => '5511999990002', 'nome' => 'Teste' }],
               trigger_rules: {})
      end

      it 'enqueues a job for each contact with phone' do
        expect(Campaigns::SendContactJob).to receive(:set).and_return(double(perform_later: true))
        service.perform
        expect(campaign.reload.campaign_status).to eq('processing')
      end
    end

    context 'when audience has no contacts with phones' do
      let(:campaign) do
        create(:campaign,
               account: account,
               inbox: api_inbox,
               campaign_type: :one_off,
               campaign_status: :active,
               audience: [{ 'type' => 'Contact', 'id' => '', 'nome' => 'Sem telefone' }],
               trigger_rules: {})
      end

      it 'marks campaign as completed immediately' do
        service.perform
        expect(campaign.reload.campaign_status).to eq('completed')
      end
    end
  end
end
