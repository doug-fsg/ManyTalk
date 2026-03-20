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
    conversation = nil

    if already_sent?(contact_inbox, campaign) && !force_resend
      Rails.logger.error("[SendContactJob] já enviado (skip): campaign_id=#{campaign.id} contact_inbox_id=#{contact_inbox.id}")
      track_success(campaign, contact_data)
      increment_processed_and_maybe_finalize(campaign)
      return
    end

    if already_sent?(contact_inbox, campaign) && force_resend
      conversation = contact_inbox.conversations.find_by(campaign_id: campaign.id)
      if conversation
        ensure_conversation_snoozed_until_reply(conversation)
        Rails.logger.error("[SendContactJob] force_resend: usando conversa existente campaign_id=#{campaign.id} conversation_id=#{conversation.id}")
      else
        conversation = create_conversation(campaign, contact_inbox)
      end
    end

    conversation ||= create_conversation(campaign, contact_inbox)
    Rails.logger.error("[SendContactJob] conversation: campaign_id=#{campaign.id} conversation_id=#{conversation.id} inbox_type=#{campaign.inbox&.inbox_type}")

    message = send_message(campaign, conversation)
    Rails.logger.error("[SendContactJob] mensagem criada no DB: campaign_id=#{campaign.id} conversation_id=#{conversation.id} message_id=#{message&.id}")

    execute_macro_if_present(campaign, conversation)

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
    phone = if contact_data['type'] == 'Contact'
              Campaigns::SpreadsheetPhoneNormalizer.normalize_to_e164(raw_phone)
            else
              legacy_normalize_phone(raw_phone)
            end

    if phone.blank?
      Rails.logger.error("[SendContactJob] normalização retornou nil: campaign_id=#{campaign.id} raw=#{raw_phone.inspect} type=#{contact_data['type']}")
      return nil
    end

    Rails.logger.error("[SendContactJob] contact encontrado/criado: campaign_id=#{campaign.id} raw=#{raw_phone.inspect} phone=#{phone}")

    name = contact_data['name'] || contact_data['nome'] || phone
    campaign.account.contacts.find_or_create_by!(phone_number: phone) do |c|
      c.name = name
    end
  rescue ActiveRecord::RecordInvalid => e
    raw_phone = phone_from(contact_data)
    normalized = contact_data['type'] == 'Contact' ? Campaigns::SpreadsheetPhoneNormalizer.normalize_to_e164(raw_phone) : legacy_normalize_phone(raw_phone)
    Rails.logger.error("[SendContactJob] RecordInvalid ao criar contact: campaign_id=#{campaign.id} raw=#{raw_phone.inspect} normalized=#{normalized.inspect} error=#{e.message}")
    campaign.account.contacts.find_by(phone_number: normalized)
  end

  def phone_from(contact_data)
    contact_data.is_a?(Hash) ? (contact_data['id'] || contact_data['phone_number']) : contact_data.to_s
  end

  def legacy_normalize_phone(raw)
    return nil if raw.blank?

    digits = raw.to_s.gsub(/\D/, '')
    return "+#{digits}" if digits.length > 11
    return "+55#{digits}" if digits.length == 11
    return "+55#{digits}" if digits.length == 10

    nil
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

  def ensure_conversation_snoozed_until_reply(conversation)
    return if conversation.open?

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

  def send_message(campaign, conversation)
    user = campaign.sender || campaign.account.administrators.first
    message = Messages::MessageBuilder.new(
      user,
      conversation,
      content: campaign.message,
      message_type: 'outgoing',
      campaign_id: campaign.id,
      macro_id: campaign.trigger_rules['macro_id'].presence
    ).perform
    message
  end

  def execute_macro_if_present(campaign, conversation)
    macro_id = campaign.trigger_rules['macro_id'].presence
    return unless macro_id

    macro = campaign.account.macros.find_by(id: macro_id)
    return unless macro

    user = campaign.sender || campaign.account.administrators.first
    MacrosExecutionJob.perform_later(macro, conversation_ids: [conversation.display_id], user: user)
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
      campaign_id: campaign.id,
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
      campaign_id: campaign.id,
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
