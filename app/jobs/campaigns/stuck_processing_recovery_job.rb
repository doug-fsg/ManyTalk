class Campaigns::StuckProcessingRecoveryJob < ApplicationJob
  queue_as :low

  STUCK_THRESHOLD_HOURS = (ENV['CAMPAIGN_STUCK_THRESHOLD_HOURS'] || 2).to_i

  def perform
    threshold = STUCK_THRESHOLD_HOURS.hours.ago

    Campaign.where(campaign_status: :processing)
            .where(campaign_type: :one_off)
            .where(updated_at: ..threshold)
            .find_each(batch_size: 50) do |campaign|
      recover_if_stuck(campaign)
    end
  end

  private

  def recover_if_stuck(campaign)
    lock_key = "campaign:#{campaign.id}:finalizing"
    got_lock = $alfred.with { |redis| redis.set(lock_key, 1, nx: true, ex: 60) }

    return unless got_lock

    heartbeat = $alfred.with { |redis| redis.get("campaign:#{campaign.id}:last_heartbeat_at").to_i }
    threshold_ts = STUCK_THRESHOLD_HOURS.hours.ago.to_i
    return if heartbeat.positive? && heartbeat > threshold_ts

    infer_and_finalize(campaign)
  ensure
    $alfred.with { |redis| redis.del(lock_key) } if got_lock
  end

  def infer_and_finalize(campaign)
    sent, failed, total, processed = read_or_infer_counters(campaign)

    new_trigger_rules = (campaign.trigger_rules || {}).merge(
      'delivery_stats' => { 'sent' => sent, 'failed' => failed, 'total' => total },
      'failed_contacts' => read_failed_list(campaign)
    )

    campaign.update_column(:trigger_rules, new_trigger_rules)
    campaign.completed!

    broadcast_recovered(campaign, sent, failed, total)
    clear_redis(campaign)

    Rails.logger.info("Campaigns::StuckProcessingRecoveryJob recovered campaign #{campaign.id}")
  end

  def read_or_infer_counters(campaign)
    sent = $alfred.with { |r| r.get("campaign:#{campaign.id}:sent_count").to_i }
    failed = $alfred.with { |r| r.get("campaign:#{campaign.id}:failed_count").to_i }
    total = $alfred.with { |r| r.get("campaign:#{campaign.id}:total_count").to_i }
    processed = $alfred.with { |r| r.get("campaign:#{campaign.id}:processed_count").to_i }

    if total.zero?
      total = campaign.trigger_rules.dig('delivery_stats', 'total').to_i
    end

    if sent.zero? && total.positive?
      sent = campaign.conversations.where(campaign_id: campaign.id).count
    end

    [sent, failed, total, processed]
  end

  def read_failed_list(campaign)
    $alfred.with do |redis|
      entries = redis.lrange("campaign:#{campaign.id}:failed_list", 0, -1)
      entries.filter_map { |e| JSON.parse(e) rescue nil }
    end
  end

  def broadcast_recovered(campaign, sent, failed, total)
    tokens = (campaign.account.agents.pluck(:pubsub_token) + campaign.account.administrators.pluck(:pubsub_token)).uniq
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
        "campaign:#{campaign.id}:finalizing",
        "campaign:#{campaign.id}:broadcast_counter",
        "campaign:#{campaign.id}:last_broadcast_at"
      )
    end
  end
end
