class Campaigns::SendContactJob < ApplicationJob
  queue_as :low
  sidekiq_options retry: 0

  FAILED_LIST_MAX = (ENV['CAMPAIGN_FAILED_LIST_MAX_SIZE'] || 1000).to_i
  SENT_LIST_MAX = (ENV['CAMPAIGN_SENT_LIST_MAX_SIZE'] || 5000).to_i
  BROADCAST_THROTTLE_SECONDS = (ENV['CAMPAIGN_BROADCAST_THROTTLE_SECONDS'] || 5).to_i
  BROADCAST_EVERY_N = (ENV['CAMPAIGN_BROADCAST_EVERY_N_CONTACTS'] || 50).to_i

  def perform(campaign_id, contact_data)
    campaign = Campaign.find_by(id: campaign_id)
    unless campaign
      Rails.logger.error("[SendContactJob] campaign não encontrada: campaign_id=#{campaign_id}")
      return
    end

    if campaign_stopped_or_paused?(campaign)
      Rails.logger.error("[SendContactJob] campaign stopped/paused (skip): campaign_id=#{campaign_id}")
      handle_stop_or_pause(campaign, contact_data)
      return
    end

    Rails.logger.error("[SendContactJob] iniciando: campaign_id=#{campaign_id} contact_data=#{contact_data.inspect}")

    contact = find_or_create_contact(campaign, contact_data)
    unless contact
      track_failure(campaign, contact_data, 'Contato inválido ou sem telefone')
      increment_processed_and_maybe_finalize(campaign)
      return
    end

    contact_inbox = build_contact_inbox(campaign, contact)
    unless contact_inbox
      Rails.logger.error("[SendContactJob] contact_inbox nil: campaign_id=#{campaign.id} contact_id=#{contact.id}")
      track_failure(campaign, contact_data, 'Não foi possível criar contact_inbox')
      increment_processed_and_maybe_finalize(campaign)
      return
    end

    Rails.logger.error("[SendContactJob] contact_inbox OK: campaign_id=#{campaign.id} contact_inbox_id=#{contact_inbox.id}")

    force_resend = campaign.trigger_rules['force_resend'] == true

    if already_sent?(contact_inbox, campaign) && !force_resend
      Rails.logger.error("[SendContactJob] já enviado (skip): campaign_id=#{campaign.id} contact_inbox_id=#{contact_inbox.id}")
      track_success(campaign, contact_data)
      increment_processed_and_maybe_finalize(campaign)
      return
    end

    conversation = resolve_conversation(campaign, contact_inbox, force_resend)
    Rails.logger.error("[SendContactJob] conversation: campaign_id=#{campaign.id} conversation_id=#{conversation.id} inbox_type=#{campaign.inbox&.inbox_type}")

    if campaign_has_macro_only?(campaign)
      if whatsapp_template_campaign?(campaign)
        track_failure(campaign, contact_data, 'Macros are not allowed for WhatsApp campaigns')
        increment_processed_and_maybe_finalize(campaign)
        return
      end

      execute_macro_if_present(campaign, conversation, contact_data)
    else
      # Disparo único: envia a mensagem da campanha
      message = send_message(campaign, conversation, contact_data)
      
      if message.blank? || !message.persisted?
        error_msg = message&.errors&.full_messages&.join(', ').presence || 'Falha ao enfileirar mensagem'
        Rails.logger.error("[SendContactJob] falha na criacao da mensagem: campaign_id=#{campaign.id} error=#{error_msg}")
        track_failure(campaign, contact_data, error_msg)
        increment_processed_and_maybe_finalize(campaign)
        return
      end
      
      # Espera simplificada para capturar erros de disparos do provedor externo (Ex: 301, WhaTicket, WPPConnect)
      sleep 2
      message.reload
      
      if message.failed?
        error_msg = message.external_error.presence || 'Erro ao enviar no provedor (status failed)'
        Rails.logger.error("[SendContactJob] falha na API: campaign_id=#{campaign.id} error=#{error_msg}")
        track_failure(campaign, contact_data, error_msg)
        increment_processed_and_maybe_finalize(campaign)
        return
      end

      Rails.logger.error("[SendContactJob] mensagem criada no DB: campaign_id=#{campaign.id} conversation_id=#{conversation.id} message_id=#{message.id}")
      execute_macro_if_present(campaign, conversation, contact_data) unless whatsapp_template_campaign?(campaign)
    end

    track_success(campaign, contact_data)
    increment_processed_and_maybe_finalize(campaign)
  rescue StandardError => e
    Rails.logger.error("Campaigns::SendContactJob failed for campaign #{campaign_id}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    campaign = Campaign.find_by(id: campaign_id)
    if campaign
      track_failure(campaign, contact_data, e.message)
      increment_processed_and_maybe_finalize(campaign)
    end
  end

  private

  def campaign_stopped_or_paused?(campaign)
    $alfred.with do |redis|
      return true if redis.get("campaign:#{campaign.id}:stop_requested").present?
      return true if redis.get("campaign:#{campaign.id}:pause_requested").present?
    end
    campaign.stopped? || campaign.paused?
  end

  def handle_stop_or_pause(campaign, contact_data)
    $alfred.with do |redis|
      redis.incr("campaign:#{campaign.id}:paused_or_stopped_count")
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", Time.current.to_i)
    end
    increment_processed_and_maybe_finalize(campaign)
  end

  def find_or_create_contact(campaign, contact_data)
    raw_phone = phone_from(contact_data)
    phone = Contacts::BrazilPhoneNormalizer.to_e164(raw_phone)

    if phone.blank?
      Rails.logger.error("[SendContactJob] normalização retornou nil: campaign_id=#{campaign.id} raw=#{raw_phone.inspect} type=#{contact_data['type']}")
      return nil
    end

    existing = Contacts::BrazilPhoneNormalizer.find_contact(
      account: campaign.account,
      phone_number: phone,
      inbox: campaign.inbox
    )
    return existing if existing

    name = contact_data['name'] || contact_data['nome'] || phone
    campaign.account.contacts.create!(phone_number: phone, name: name)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[SendContactJob] RecordInvalid ao criar contact: campaign_id=#{campaign.id} raw=#{raw_phone.inspect} phone=#{phone.inspect} error=#{e.message}")
    Contacts::BrazilPhoneNormalizer.find_contact(
      account: campaign.account,
      phone_number: phone,
      inbox: campaign.inbox
    )
  end

  def phone_from(contact_data)
    contact_data.is_a?(Hash) ? (contact_data['id'] || contact_data['phone_number']) : contact_data.to_s
  end

  def build_contact_inbox(campaign, contact)
    phone_digits = contact.phone_number.delete('+')
    ContactInboxBuilder.new(
      contact: contact,
      inbox: campaign.inbox,
      source_id: phone_digits
    ).perform
  rescue StandardError => e
    Rails.logger.error("[SendContactJob] ContactInboxBuilder failed: #{e.message}")
    nil
  end

  def already_sent?(contact_inbox, campaign)
    contact_inbox.conversations.exists?(campaign_id: campaign.id)
  end

  def resolve_conversation(campaign, contact_inbox, force_resend)
    open_conversation = reusable_open_conversation(contact_inbox)
    if open_conversation
      remember_campaign_on(open_conversation, campaign)
      return open_conversation
    end

    if force_resend
      existing = contact_inbox.conversations.find_by(campaign_id: campaign.id)
      if existing
        ensure_conversation_snoozed_until_reply(existing)
        return existing
      end
    end

    create_conversation(campaign, contact_inbox)
  end

  # Open threads in progress must stay visible. Assigned open conversations
  # are never moved to snoozed by a campaign send.
  def reusable_open_conversation(contact_inbox)
    contact_inbox.conversations.open.order(updated_at: :desc).first
  end

  def remember_campaign_on(conversation, campaign)
    return if conversation.campaign_id.present?

    conversation.update_column(:campaign_id, campaign.id)
  end

  def ensure_conversation_snoozed_until_reply(conversation)
    return if conversation.open?
    return if conversation.snoozed?

    conversation.update!(status: :snoozed, snoozed_until: nil)
  end

  def create_conversation(campaign, contact_inbox)
    Conversation.create!(
      account_id: campaign.account_id,
      inbox_id: campaign.inbox_id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      campaign_id: campaign.id,
      status: :snoozed,
      snoozed_until: nil,
      additional_attributes: { campaign_id: campaign.id }
    )
  end

  def send_message(campaign, conversation, contact_data = {})
    if whatsapp_template_campaign?(campaign)
      return send_whatsapp_template_message(campaign, conversation, contact_data)
    end

    content = substitute_message_variables(campaign.message, contact_data, conversation.contact)
    user = campaign.sender || campaign.account.administrators.first
    message = Messages::MessageBuilder.new(
      user,
      conversation,
      content: content,
      message_type: 'outgoing',
      campaign_id: campaign.id,
      macro_id: campaign.trigger_rules['macro_id'].presence
    ).perform
    message
  end

  def substitute_message_variables(text, contact_data, contact = nil)
    return text if text.blank?

    # @nome: planilha (nome), label (name no contact_data), ou fallback no contact do banco
    nome = contact_data['nome'].presence || contact_data['name'].presence || contact&.name.presence || ''
    variavel = contact_data['variavel'].presence || ''

    if text.match?(/@nome/i) && nome.blank?
      raise 'A mensagem exige a variável @nome, mas ela está vazia ou não preenchida na planilha.'
    end

    if text.match?(/@variavel/i) && variavel.blank?
      raise 'A mensagem exige a variável @variavel, mas ela está vazia na planilha.'
    end

    text
      .gsub(/@nome/i, nome.to_s)
      .gsub(/@variavel/i, variavel.to_s)
  end

  def whatsapp_template_campaign?(campaign)
    campaign.inbox.whatsapp? && campaign.trigger_rules['send_mode'] == 'template_only'
  end

  def send_whatsapp_template_message(campaign, conversation, contact_data)
    user = campaign.sender || campaign.account.administrators.first
    template_params = Campaigns::TemplateParamsInterpolator.new(
      campaign: campaign,
      conversation: conversation,
      contact_data: contact_data,
      sender: user
    ).perform

    if template_params.blank?
      raise 'WhatsApp template is required'
    end

    content = template_preview_content(template_params)
    Messages::MessageBuilder.new(
      user,
      conversation,
      content: content,
      template_params: template_params,
      message_type: 'outgoing',
      campaign_id: campaign.id
    ).perform
  end

  def template_preview_content(template_params)
    processed = template_params['processed_params']
    return template_params['name'] if processed.blank?

    if processed.is_a?(Hash)
      processed.values.flatten.compact.join(' ').presence || template_params['name']
    else
      template_params['name']
    end
  end

  def campaign_has_macro_only?(campaign)
    campaign.trigger_rules['macro_id'].present?
  end

  def execute_macro_if_present(campaign, conversation, contact_data = nil)
    return if whatsapp_template_campaign?(campaign)

    macro_id = campaign.trigger_rules['macro_id'].presence
    return unless macro_id

    macro = campaign.account.macros.find_by(id: macro_id)
    return unless macro

    user = campaign.sender || campaign.account.administrators.first
    MacrosExecutionJob.perform_later(macro, conversation_ids: [conversation.display_id], user: user, contact_data: contact_data)
  end

  def track_success(campaign, contact_data = nil)
    $alfred.with do |redis|
      redis.incr("campaign:#{campaign.id}:sent_count")
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", Time.current.to_i)
      if contact_data.present?
        entry = { contact: contact_data, status: 'success' }.to_json
        redis.rpush("campaign:#{campaign.id}:sent_list", entry)
        redis.ltrim("campaign:#{campaign.id}:sent_list", -SENT_LIST_MAX, -1)
      end
    end
  end

  def track_failure(campaign, contact_data, error)
    Rails.logger.error("[SendContactJob] track_failure: campaign_id=#{campaign.id} error=#{error} contact=#{contact_data.inspect}")
    $alfred.with do |redis|
      redis.incr("campaign:#{campaign.id}:failed_count")
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", Time.current.to_i)
      entry = { contact: contact_data, error: error.to_s }.to_json
      redis.rpush("campaign:#{campaign.id}:failed_list", entry)
      redis.ltrim("campaign:#{campaign.id}:failed_list", -FAILED_LIST_MAX, -1)
    end
  end

  def increment_processed_and_maybe_finalize(campaign)
    $alfred.with do |redis|
      redis.incr("campaign:#{campaign.id}:processed_count")
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", Time.current.to_i)
    end

    broadcast_progress(campaign)
    finalize_if_done(campaign)
  end

  def should_broadcast?(campaign)
    $alfred.with do |redis|
      counter = redis.incr("campaign:#{campaign.id}:broadcast_counter").to_i
      last_at = redis.get("campaign:#{campaign.id}:last_broadcast_at").to_i
      now = Time.current.to_i

      if last_at.zero? || (now - last_at >= BROADCAST_THROTTLE_SECONDS) || (counter % BROADCAST_EVERY_N == 0)
        redis.set("campaign:#{campaign.id}:last_broadcast_at", now)
        true
      else
        false
      end
    end
  end

  def broadcast_progress(campaign)
    return unless should_broadcast?(campaign)

    sent, failed, total = read_counters(campaign)
    tokens = admin_and_agent_tokens(campaign.account)
    return if tokens.blank?

    payload = {
      campaign_id: campaign.display_id,
      account_id: campaign.account_id,
      sent: sent,
      failed: failed,
      total: total,
      status: campaign.campaign_status
    }
    ActionCableBroadcastJob.perform_later(tokens, 'campaign.progress', payload)
  end

  def finalize_if_done(campaign)
    return if campaign.completed?
    return if campaign.paused? || campaign.stopped?

    processed, total = read_processed_and_total(campaign)
    return unless processed >= total

    return unless acquire_finalize_lock(campaign)

    sent, failed, = read_counters(campaign)
    failed_list = read_failed_list(campaign)
    sent_list = read_sent_list(campaign)
    new_trigger_rules = (campaign.trigger_rules || {}).except('force_resend').merge(
      'delivery_stats' => { 'sent' => sent, 'failed' => failed, 'total' => total },
      'failed_contacts' => failed_list,
      'successful_contacts' => sent_list
    )

    campaign.update_column(:trigger_rules, new_trigger_rules)
    campaign.completed!

    broadcast_completed(campaign, sent, failed, total)
    clear_redis(campaign)
  end

  def acquire_finalize_lock(campaign)
    lock_key = "campaign:#{campaign.id}:finalizing"
    $alfred.with do |redis|
      redis.set(lock_key, 1, nx: true, ex: 60)
    end
  end

  def broadcast_completed(campaign, sent, failed, total)
    tokens = admin_and_agent_tokens(campaign.account)
    return if tokens.blank?

    payload = {
      campaign_id: campaign.display_id,
      account_id: campaign.account_id,
      sent: sent,
      failed: failed,
      total: total,
      status: 'completed'
    }
    ActionCableBroadcastJob.perform_later(tokens, 'campaign.progress', payload)
  end

  def read_counters(campaign)
    $alfred.with do |redis|
      sent = redis.get("campaign:#{campaign.id}:sent_count").to_i
      failed = redis.get("campaign:#{campaign.id}:failed_count").to_i
      total = redis.get("campaign:#{campaign.id}:total_count").to_i
      [sent, failed, total]
    end
  end

  def read_processed_and_total(campaign)
    $alfred.with do |redis|
      processed = redis.get("campaign:#{campaign.id}:processed_count").to_i
      total = redis.get("campaign:#{campaign.id}:total_count").to_i
      [processed, total]
    end
  end

  def read_failed_list(campaign)
    $alfred.with do |redis|
      entries = redis.lrange("campaign:#{campaign.id}:failed_list", 0, -1)
      entries.filter_map { |e| JSON.parse(e) rescue nil }
    end
  end

  def read_sent_list(campaign)
    $alfred.with do |redis|
      entries = redis.lrange("campaign:#{campaign.id}:sent_list", 0, -1)
      entries.filter_map { |e| JSON.parse(e) rescue nil }
    end
  end

  def clear_redis(campaign)
    $alfred.with do |redis|
      redis.del(
        "campaign:#{campaign.id}:sent_count",
        "campaign:#{campaign.id}:failed_count",
        "campaign:#{campaign.id}:total_count",
        "campaign:#{campaign.id}:processed_count",
        "campaign:#{campaign.id}:paused_or_stopped_count",
        "campaign:#{campaign.id}:last_heartbeat_at",
        "campaign:#{campaign.id}:failed_list",
        "campaign:#{campaign.id}:sent_list",
        "campaign:#{campaign.id}:finalizing",
        "campaign:#{campaign.id}:broadcast_counter",
        "campaign:#{campaign.id}:last_broadcast_at"
      )
    end
  end

  def admin_and_agent_tokens(account)
    (account.agents.pluck(:pubsub_token) + account.administrators.pluck(:pubsub_token)).uniq
  end
end
