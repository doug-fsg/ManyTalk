class Whatsapp::OneoffWhatsappCampaignService
  pattr_initialize [:campaign!]

  DEFAULT_DELAY_SECONDS = 5

  def perform
    validate!

    resolver = Campaigns::AudienceResolver.new(campaign: campaign)
    total = resolver.deliverable_count

    if total.zero?
      campaign.completed!
      return
    end

    campaign.processing!
    init_redis_counters(campaign, total)
    persist_initial_snapshot(campaign, total)

    delay_seconds = (ENV['CAMPANHA_DELAY_SECONDS'] || DEFAULT_DELAY_SECONDS).to_i
    enqueue_contacts(resolver, delay_seconds)
  end

  private

  def validate!
    raise "Invalid campaign #{campaign.id}" unless campaign.inbox.whatsapp? && campaign.one_off?
    raise 'Campaign is already completed' if campaign.completed?
    raise 'Campaign is already processing' if campaign.processing?
    raise 'Campaign is paused' if campaign.paused?
    raise 'Campaign is stopped' if campaign.stopped?
    raise 'WhatsApp template is required' if campaign.trigger_rules['template_params'].blank?
    raise 'Macros are not allowed for WhatsApp campaigns' if campaign.trigger_rules['macro_id'].present?
  end

  def enqueue_contacts(resolver, delay_seconds)
    resolver.each_deliverable_contact.with_index do |contact_data, index|
      Campaigns::SendContactJob.set(wait: (index * delay_seconds).seconds).perform_later(campaign.id, contact_data)
    end
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
