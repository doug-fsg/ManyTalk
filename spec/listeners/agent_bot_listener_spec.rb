require 'rails_helper'
describe AgentBotListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:agent_bot) { create(:agent_bot, capitao: true) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, capitao_enabled: true) }

  describe '#message_created' do
    let(:event_name) { 'message.created' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }
    let!(:message) do
      create(:message, message_type: 'incoming',
                       account: account, inbox: inbox, conversation: conversation)
    end

    context 'when agent bot is not configured' do
      it 'does not send message to agent bot' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).exactly(0).times
        listener.message_created(event)
      end
    end

    context 'when agent bot is configured' do
      before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot) }

      it 'sends message to agent bot when capitao is enabled' do
        expect(AgentBots::WebhookJob).to receive(:perform_later) do |url, payload|
          expect(url).to eq(agent_bot.outgoing_url)
          expect(payload[:event]).to eq('message_created')
          expect(payload[:conversation][:capitao_agent]).to be_nil
        end
        listener.message_created(event)
      end

      it 'includes selected capitao agent in webhook payload' do
        conversation.update!(capitao_agent: { 'id' => 'agt_vendas', 'name' => 'Vendas' })
        expect(AgentBots::WebhookJob).to receive(:perform_later) do |url, payload|
          expect(url).to eq(agent_bot.outgoing_url)
          expect(payload[:conversation][:capitao_agent]).to eq({ 'id' => 'agt_vendas', 'name' => 'Vendas' })
        end
        listener.message_created(event)
      end

      it 'sends message to agent bot when conversation is pending' do
        conversation.update!(status: :pending)
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(agent_bot.outgoing_url,
                                                                      message.webhook_data.merge(event: 'message_created')).once
        listener.message_created(event)
      end

      it 'does not send message to agent bot if url is empty' do
        agent_bot.update!(outgoing_url: '')
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.message_created(event)
      end

      it 'does not send message when capitao is disabled on capitao bot' do
        conversation.update!(capitao_enabled: false)
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.message_created(event)
      end

      it 'sends message when capitao is disabled but bot is not capitao' do
        agent_bot.update!(capitao: false)
        conversation.update!(capitao_enabled: false)
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(agent_bot.outgoing_url,
                                                                      message.webhook_data.merge(event: 'message_created')).once
        listener.message_created(event)
      end

      it 'does not send echo messages from the agent bot' do
        echo = create(:message, message_type: 'outgoing', account: account, inbox: inbox,
                                conversation: conversation, sender: agent_bot)
        echo_event = Events::Base.new(event_name, Time.zone.now, message: echo)
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.message_created(echo_event)
      end
    end

    context 'when agent bot csml type is configured' do
      it 'sends message to agent bot' do
        agent_bot_csml = create(:agent_bot, :skip_validate, bot_type: 'csml')
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot_csml)
        expect(AgentBots::CsmlJob).to receive(:perform_later).with('message.created', agent_bot_csml, message).once
        listener.message_created(event)
      end
    end
  end

  describe '#webwidget_triggered' do
    let(:event_name) { 'webwidget.triggered' }

    context 'when agent bot is configured' do
      it 'send message to agent bot URL' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

        event = double
        allow(event).to receive(:data)
          .and_return(
            {
              contact_inbox: conversation.contact_inbox,
              event_info: { country: 'US' }
            }
          )
        expect(AgentBots::WebhookJob).to receive(:perform_later)
          .with(
            agent_bot.outgoing_url,
            conversation.contact_inbox.webhook_data.merge(event: 'webwidget_triggered', event_info: { country: 'US' })
          ).once

        listener.webwidget_triggered(event)
      end

      it 'does not send message when capitao is disabled on active conversation' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        conversation.update!(capitao_enabled: false)

        event = double
        allow(event).to receive(:data)
          .and_return(
            {
              contact_inbox: conversation.contact_inbox,
              event_info: { country: 'US' }
            }
          )
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)

        listener.webwidget_triggered(event)
      end
    end
  end

  describe '#conversation_opened' do
    let(:event_name) { 'conversation.opened' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    context 'when agent bot is configured' do
      before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot) }

      it 'sends event to agent bot when capitao is enabled' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          conversation.webhook_data.merge(event: 'conversation_opened')
        ).once

        listener.conversation_opened(event)
      end

      it 'does not send event when capitao is disabled' do
        conversation.update!(capitao_enabled: false)

        expect(AgentBots::WebhookJob).not_to receive(:perform_later)

        listener.conversation_opened(event)
      end
    end
  end

  describe '#conversation_resolved' do
    let(:event_name) { 'conversation.resolved' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    context 'when agent bot is configured' do
      before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot) }

      it 'sends event to agent bot when capitao is enabled' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          conversation.webhook_data.merge(event: 'conversation_resolved')
        ).once

        listener.conversation_resolved(event)
      end

      it 'does not send event when capitao is disabled' do
        conversation.update!(capitao_enabled: false)

        expect(AgentBots::WebhookJob).not_to receive(:perform_later)

        listener.conversation_resolved(event)
      end
    end
  end
end
