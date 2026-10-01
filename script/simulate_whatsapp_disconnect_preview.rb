# frozen_string_literal: true

# Simula erro de canal WhatsApp desconectado (133010) para preview no front.
# Uso: RAILS_ENV=development bundle exec rails runner script/simulate_whatsapp_disconnect_preview.rb [inbox_id]
#
# Reverter: RAILS_ENV=development bundle exec rails runner script/simulate_whatsapp_disconnect_preview.rb --revert [inbox_id]

inbox_id = ARGV.find { |a| a.match?(/\A\d+\z/) }&.to_i
revert = ARGV.include?('--revert')

scope = Channel::Whatsapp.where(provider: 'whatsapp_cloud')
channel = if inbox_id
            Inbox.find(inbox_id).channel
          else
            scope.find { |c| c.provider_config['source'] == 'embedded_signup' } || scope.first
          end

raise 'Nenhum canal WhatsApp Cloud encontrado' unless channel.is_a?(Channel::Whatsapp)

inbox = channel.inbox
message = inbox.messages.where(message_type: :outgoing).order(id: :desc).first

if revert
  channel.reauthorized!
  if message && message.content_attributes&.[]('external_error').present?
    attrs = message.content_attributes.except('external_error')
    message.update!(content_attributes: attrs, status: :sent) if message.status == 'failed'
  end
  inbox.update_account_cache
  puts "REVERTED inbox=#{inbox.id} channel=#{channel.id}"
  exit 0
end

channel.prompt_reauthorization! unless channel.reauthorization_required?
error_text = I18n.t('conversations.messages.whatsapp.errors.channel_disconnected')

if message
  attrs = (message.content_attributes || {}).merge('external_error' => error_text)
  message.update!(status: :failed, content_attributes: attrs)
end

inbox.update_account_cache

puts "SIMULATED disconnect preview"
puts "  account_id=#{inbox.account_id}"
puts "  inbox_id=#{inbox.id}"
puts "  conversation_id=#{message&.conversation_id}"
puts "  reauthorization_required=#{channel.reauthorization_required?}"
puts "  open: /app/accounts/#{inbox.account_id}/conversations/#{message.conversation_id}"
puts "  settings: /app/accounts/#{inbox.account_id}/settings/inboxes/#{inbox.id}"
puts "  revert: bundle exec rails runner script/simulate_whatsapp_disconnect_preview.rb --revert #{inbox.id}"
