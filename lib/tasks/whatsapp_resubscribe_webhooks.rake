# frozen_string_literal: true

namespace :whatsapp do
  desc 'Re-subscribe WhatsApp Cloud webhooks (includes smb_message_echoes for coexistence)'
  task resubscribe_webhooks: :environment do
    channels = Channel::Whatsapp.where(provider: 'whatsapp_cloud')
    puts "Re-subscribing #{channels.count} WhatsApp Cloud channel(s)..."

    channels.find_each do |channel|
      business_account_id = channel.provider_config['business_account_id']
      api_key = channel.provider_config['api_key']

      if business_account_id.blank? || api_key.blank?
        puts "[SKIP] #{channel.phone_number} — missing business_account_id or api_key"
        next
      end

      Whatsapp::WebhookSetupService.new(channel, business_account_id, api_key).perform
      puts "[OK] #{channel.phone_number}"
    rescue StandardError => e
      puts "[FAIL] #{channel.phone_number} — #{e.message}"
    end
  end
end
