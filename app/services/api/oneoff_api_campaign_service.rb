class Api::OneoffApiCampaignService
  pattr_initialize [:campaign!]

  DEFAULT_DELAY_SECONDS = 5
  LABEL_BATCH_SIZE = 500

  def perform
    validate!

    audience_contacts = resolve_audience_contacts
    label_relation = resolve_label_relation

    total = count_total(label_relation, audience_contacts)

    if total.zero?
      campaign.completed!
      return
    end

    campaign.processing!
    init_redis_counters(campaign, total)
    persist_initial_snapshot(campaign, total)

    delay_seconds = (ENV['CAMPANHA_DELAY_SECONDS'] || DEFAULT_DELAY_SECONDS).to_i
    index = enqueue_label_contacts(label_relation, delay_seconds, 0)
    enqueue_audience_contacts(audience_contacts, delay_seconds, index)
  end

  private

  def validate!
    raise "Invalid campaign #{campaign.id}" unless campaign.inbox.inbox_type == 'API' && campaign.one_off?
    raise 'Campaign is already completed' if campaign.completed?
    raise 'Campaign is already processing' if campaign.processing?
    raise 'Campaign is paused' if campaign.paused?
    raise 'Campaign is stopped' if campaign.stopped?
    raise 'Inbox webhook URL is not configured' if campaign.inbox.channel.webhook_url.blank?
  end

  def resolve_audience_contacts
    campaign.audience.to_a.select { |a| a['type'] == 'Contact' && phone_from(a).present? }
  end

  def resolve_label_relation(label_ids = nil)
    ids = label_ids || campaign.audience.to_a.select { |a| a['type'] == 'Label' }.map { |a| a['id'] }
    return Contact.none if ids.blank?

    labels = campaign.account.labels.where(id: ids).pluck(:title)
    return Contact.none if labels.blank?

    label_pattern = labels.map { |l| Regexp.escape(l) }.join('|')

    conversation_contact_ids = campaign.account.contacts
                                       .joins(:conversations)
                                       .merge(campaign.account.conversations.tagged_with(labels, any: true))
                                       .distinct
                                       .pluck('contacts.id')

    conversation_contact_ids |= campaign.account.contacts
                                        .joins(:conversations)
                                        .where('conversations.cached_label_list ~* ?', label_pattern)
                                        .distinct
                                        .pluck('contacts.id')

    contact_label_ids = campaign.account.contacts
                                .tagged_with(labels, any: true)
                                .pluck(:id)

    merged_ids = conversation_contact_ids | contact_label_ids
    return Contact.none if merged_ids.empty?

    campaign.account.contacts.where(id: merged_ids)
  end

  def count_total(label_relation, audience_contacts)
    label_count = label_relation.respond_to?(:count) ? label_relation.count : 0
    label_count + audience_contacts.size
  end

  def enqueue_label_contacts(label_relation, delay_seconds, start_index)
    return start_index unless label_relation.respond_to?(:find_each)

    idx = start_index
    label_relation.find_each(batch_size: LABEL_BATCH_SIZE) do |contact|
      contact_data = { 'type' => 'Label', 'id' => contact.phone_number, 'name' => contact.name, 'db_id' => contact.id }
      next unless phone_from(contact_data).present?

      Campaigns::SendContactJob.set(wait: (idx * delay_seconds).seconds).perform_later(campaign.id, contact_data)
      idx += 1
    end
    idx
  end

  def enqueue_audience_contacts(audience_contacts, delay_seconds, start_index)
    audience_contacts.each_with_index do |contact_data, i|
      index = start_index + i
      Campaigns::SendContactJob.set(wait: (index * delay_seconds).seconds).perform_later(campaign.id, contact_data)
    end
  end

  def phone_from(contact_data)
    contact_data.is_a?(Hash) ? (contact_data['id'] || contact_data['phone_number']) : contact_data.to_s
  end

  def init_redis_counters(campaign, total)
    now = Time.current.to_i
    $alfred.with do |redis|
      redis.set("campaign:#{campaign.id}:total_count", total)
      redis.set("campaign:#{campaign.id}:processed_count", 0)
      redis.set("campaign:#{campaign.id}:sent_count", 0)
      redis.set("campaign:#{campaign.id}:failed_count", 0)
      redis.set("campaign:#{campaign.id}:paused_or_stopped_count", 0)
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", now)
      redis.del("campaign:#{campaign.id}:failed_list")
    end
  end

  def persist_initial_snapshot(campaign, total)
    campaign.update_column(
      :trigger_rules,
      (campaign.trigger_rules || {}).merge('delivery_stats' => { 'total' => total, 'sent' => 0, 'failed' => 0 })
    )
  end
end
