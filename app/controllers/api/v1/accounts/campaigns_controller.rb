class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 15

  before_action :campaign, except: [:index, :create]
  before_action :check_authorization

  def index
    @campaigns = resolved_campaigns.page(current_page).per(per_page)
    @campaigns_count = resolved_campaigns.count
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params)
  end

  def update
    @campaign = Current.account.campaigns.find_by(display_id: params[:id])

    filtered_params = campaign_params.except(:audience)

    if @campaign.update(filtered_params)
      if campaign_params[:audience].present?
        formatted_audience = campaign_params[:audience].map do |item|
          { id: item[:id], type: item[:type], nome: item[:nome], variavel: item[:variavel] }
        end
        @campaign.update_column(:audience, JSON.parse(JSON.generate(formatted_audience)))
      end

      render json: @campaign
    else
      render json: { errors: @campaign.errors }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def progress
    render json: campaign_progress(@campaign)
  end

  def retry_failed
    failed_contacts = retry_contacts_param
    return render json: { errors: 'No contacts to retry' }, status: :unprocessable_entity if failed_contacts.blank?

    new_rules = (@campaign.trigger_rules || {}).merge('force_resend' => true)
    @campaign.update_column(:trigger_rules, new_rules)

    delay_seconds = (ENV['CAMPANHA_DELAY_SECONDS'] || 5).to_i

    @campaign.processing! if @campaign.completed?
    init_retry_redis(@campaign, failed_contacts.length)

    failed_contacts.each_with_index do |contact_data, index|
      Campaigns::SendContactJob.set(wait: (index * delay_seconds).seconds).perform_later(
        @campaign.id,
        contact_data
      )
    end

    render json: { message: "Retrying #{failed_contacts.length} contacts" }
  end

  def resend
    return render json: { errors: 'Only completed or stopped campaigns can be resent' }, status: :unprocessable_entity unless @campaign.completed? || @campaign.stopped?

    audience_contacts = resolve_audience_contacts_for_resend

    return render json: { errors: 'No contacts to resend' }, status: :unprocessable_entity if audience_contacts.blank?

    new_rules = (@campaign.trigger_rules || {}).merge('force_resend' => true)
    @campaign.update_column(:trigger_rules, new_rules)

    delay_seconds = (ENV['CAMPANHA_DELAY_SECONDS'] || 5).to_i
    @campaign.processing!

    init_resend_redis(@campaign, audience_contacts.length)

    audience_contacts.each_with_index do |contact_data, index|
      Campaigns::SendContactJob.set(wait: (index * delay_seconds).seconds).perform_later(
        @campaign.id,
        contact_data
      )
    end

    render json: { message: "Resending to #{audience_contacts.length} contacts" }
  rescue StandardError => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end

  def pause
    return render json: { errors: 'Campaign must be processing to pause' }, status: :unprocessable_entity unless @campaign.processing?

    $alfred.with { |redis| redis.set("campaign:#{@campaign.id}:pause_requested", 1) }
    persist_partial_stats(@campaign)
    @campaign.paused!
    broadcast_campaign_status(@campaign, 'paused')
    render :pause
  end

  def stop
    return render json: { errors: 'Campaign must be processing or active to stop' }, status: :unprocessable_entity unless (@campaign.processing? || @campaign.active?)

    if @campaign.processing?
      $alfred.with { |redis| redis.set("campaign:#{@campaign.id}:stop_requested", 1) }
      persist_partial_stats(@campaign)
    end
    @campaign.stopped!
    broadcast_campaign_status(@campaign, 'stopped')
    render :stop
  end

  def resume
    return render json: { errors: 'Only paused campaigns can be resumed' }, status: :unprocessable_entity unless @campaign.paused?

    audience_contacts = resolve_audience_contacts_for_resend
    return render json: { errors: 'No contacts found in campaign audience' }, status: :unprocessable_entity if audience_contacts.blank?

    sent_list = read_sent_contacts_from_rules(@campaign)
    failed_list = read_failed_contacts_from_rules(@campaign)
    
    # Identifica contatos que já foram processados
    processed_phones = (sent_list + failed_list).map do |entry|
      # Entry has format: {"contact" => { "id" => "123", ...}, "status" => "..."} OR {"contact" => "123", ...}
      contact_data = entry.is_a?(Hash) && entry.key?('contact') ? entry['contact'] : entry
      
      if contact_data.is_a?(Hash)
        (contact_data['id'] || contact_data['phone_number']).to_s
      else
        contact_data.to_s
      end
    end.compact.reject(&:empty?)

    pending_contacts = audience_contacts.reject do |contact_data|
      phone = contact_data['id'] || contact_data['phone_number']
      processed_phones.include?(phone.to_s)
    end

    if pending_contacts.blank?
      @campaign.completed!
      broadcast_campaign_status(@campaign, 'completed')
      return render json: { message: 'All contacts were all processed before resuming', status: 'completed' }
    end

    $alfred.with do |redis|
      redis.del("campaign:#{@campaign.id}:pause_requested")
      redis.del("campaign:#{@campaign.id}:stop_requested")
      
      # Restauramos os contadores exatos para que SendContactJob não termine antes da hora 
      # e nem calcule porcentagens erradas
      redis.set("campaign:#{@campaign.id}:total_count", audience_contacts.length)
      redis.set("campaign:#{@campaign.id}:processed_count", processed_phones.length)
      redis.set("campaign:#{@campaign.id}:sent_count", sent_list.length)
      redis.set("campaign:#{@campaign.id}:failed_count", failed_list.length)
      redis.set("campaign:#{@campaign.id}:paused_or_stopped_count", 0)
    end

    @campaign.processing!
    
    clear_scheduled_jobs_for_campaign(@campaign.id)

    delay_seconds = (ENV['CAMPANHA_DELAY_SECONDS'] || 5).to_i
    
    pending_contacts.each_with_index do |contact_data, index|
      Campaigns::SendContactJob.set(wait: (index * delay_seconds).seconds).perform_later(
        @campaign.id,
        contact_data
      )
    end

    broadcast_campaign_status(@campaign, 'processing')
    render :resume
  rescue StandardError => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end

  private

  def read_sent_contacts_from_rules(campaign)
    campaign.trigger_rules['successful_contacts'] || []
  end

  def read_failed_contacts_from_rules(campaign)
    campaign.trigger_rules['failed_contacts'] || []
  end

  def campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def resolved_campaigns
    scope = Current.account.campaigns.order(created_at: :desc)
    scope = scope.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
    scope = scope.where(campaign_status: params[:campaign_status]) if params[:campaign_status].present?
    scope = scope.where('title ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    scope
  end

  def current_page
    (params[:page].presence || 1).to_i
  end

  def per_page
    n = params[:per_page].to_i
    n.positive? ? [n, 100].min : RESULTS_PER_PAGE
  end

  def campaign_params
    params.require(:campaign).permit(:title, :description, :message, :enabled, :trigger_only_during_business_hours, :inbox_id, :sender_id,
                                     :scheduled_at, :campaign_status, audience: [:type, :id, :nome, :variavel], trigger_rules: {})
  end

  def retry_contacts_param
    contacts = params[:contacts]
    return @campaign.trigger_rules['failed_contacts'] if contacts.blank?

    contacts.permit!.to_a.map(&:to_h)
  rescue StandardError
    @campaign.trigger_rules['failed_contacts'] || []
  end

  def campaign_progress(campaign)
    if campaign.processing?
      read_live_progress(campaign)
    else
      stats = campaign.trigger_rules['delivery_stats'] || {}
      {
        campaign_id: campaign.display_id,
        status: campaign.campaign_status,
        sent: stats['sent'].to_i,
        failed: stats['failed'].to_i,
        total: stats['total'].to_i,
        failed_contacts: campaign.trigger_rules['failed_contacts'] || [],
        successful_contacts: campaign.trigger_rules['successful_contacts'] || []
      }
    end
  end

  def read_live_progress(campaign)
    $alfred.with do |redis|
      sent_list = redis.lrange("campaign:#{campaign.id}:sent_list", 0, -1).filter_map { |e| JSON.parse(e) rescue nil }
      failed_list = redis.lrange("campaign:#{campaign.id}:failed_list", 0, -1).filter_map { |e| JSON.parse(e) rescue nil }
      {
        campaign_id: campaign.display_id,
        status: campaign.campaign_status,
        sent: redis.get("campaign:#{campaign.id}:sent_count").to_i,
        failed: redis.get("campaign:#{campaign.id}:failed_count").to_i,
        total: redis.get("campaign:#{campaign.id}:total_count").to_i,
        failed_contacts: failed_list,
        successful_contacts: sent_list
      }
    end
  end

  def init_retry_redis(campaign, count)
    now = Time.current.to_i
    $alfred.with do |redis|
      total = redis.get("campaign:#{campaign.id}:total_count").to_i
      
      if total.zero? && campaign.trigger_rules.present? && campaign.trigger_rules['delivery_stats'].present?
        stats = campaign.trigger_rules['delivery_stats']
        base_total = stats['total'].to_i
        base_sent = stats['sent'].to_i
        
        redis.set("campaign:#{campaign.id}:total_count", base_total)
        redis.set("campaign:#{campaign.id}:processed_count", [base_total - count, 0].max)
        redis.set("campaign:#{campaign.id}:sent_count", base_sent)
        redis.set("campaign:#{campaign.id}:failed_count", [(stats['failed'].to_i - count), 0].max)
        redis.set("campaign:#{campaign.id}:paused_or_stopped_count", 0)

        sent_list = campaign.trigger_rules['successful_contacts'] || []
        sent_list.each { |item| redis.rpush("campaign:#{campaign.id}:sent_list", item.to_json) }
        redis.ltrim("campaign:#{campaign.id}:sent_list", -5000, -1)
      elsif total.zero?
        redis.set("campaign:#{campaign.id}:total_count", count)
        redis.set("campaign:#{campaign.id}:processed_count", 0)
        redis.set("campaign:#{campaign.id}:sent_count", 0)
        redis.set("campaign:#{campaign.id}:failed_count", 0)
        redis.set("campaign:#{campaign.id}:paused_or_stopped_count", 0)
      else
        new_total = total + count
        redis.set("campaign:#{campaign.id}:total_count", new_total)
      end
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", now)
    end
  end

  def resolve_audience_contacts_for_resend
    @campaign.audience.to_a.select { |a| a['id'].present? }
  end

  def init_resend_redis(campaign, count)
    now = Time.current.to_i
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
        "campaign:#{campaign.id}:last_broadcast_at",
        "campaign:#{campaign.id}:stop_requested",
        "campaign:#{campaign.id}:pause_requested"
      )
      redis.set("campaign:#{campaign.id}:total_count", count)
      redis.set("campaign:#{campaign.id}:processed_count", 0)
      redis.set("campaign:#{campaign.id}:sent_count", 0)
      redis.set("campaign:#{campaign.id}:failed_count", 0)
      redis.set("campaign:#{campaign.id}:paused_or_stopped_count", 0)
      redis.set("campaign:#{campaign.id}:last_heartbeat_at", now)
    end
  end

  def persist_partial_stats(campaign)
    sent, failed, total = $alfred.with do |redis|
      [
        redis.get("campaign:#{campaign.id}:sent_count").to_i,
        redis.get("campaign:#{campaign.id}:failed_count").to_i,
        redis.get("campaign:#{campaign.id}:total_count").to_i
      ]
    end
    total = campaign.trigger_rules.dig('delivery_stats', 'total').to_i if total.zero? && campaign.trigger_rules.present?
    return if total.zero?

    failed_list, sent_list = $alfred.with do |redis|
      f_list = redis.lrange("campaign:#{campaign.id}:failed_list", 0, -1).filter_map { |e| JSON.parse(e) rescue nil }
      s_list = redis.lrange("campaign:#{campaign.id}:sent_list", 0, -1).filter_map { |e| JSON.parse(e) rescue nil }
      [f_list, s_list]
    end
    
    new_rules = (campaign.trigger_rules || {}).merge(
      'delivery_stats' => { 'sent' => sent, 'failed' => failed, 'total' => total },
      'failed_contacts' => failed_list,
      'successful_contacts' => sent_list
    )
    campaign.update_column(:trigger_rules, new_rules)
  end

  def broadcast_campaign_status(campaign, status)
    sent, failed, total = read_live_progress(campaign).values_at(:sent, :failed, :total)
    tokens = (campaign.account.agents.pluck(:pubsub_token) + campaign.account.administrators.pluck(:pubsub_token)).uniq
    return if tokens.blank?

    payload = {
      campaign_id: campaign.display_id,
      account_id: campaign.account_id,
      sent: sent,
      failed: failed,
      total: total,
      status: status
    }
    ActionCableBroadcastJob.perform_later(tokens, 'campaign.progress', payload)
  end

  def clear_scheduled_jobs_for_campaign(campaign_id)
    require 'sidekiq/api'
    
    [Sidekiq::ScheduledSet.new, Sidekiq::Queue.new('low')].each do |queue|
      queue.each do |job|
        job_wrapper = job.args.first
        next unless job_wrapper.is_a?(Hash)
        
        if job_wrapper['job_class'] == 'Campaigns::SendContactJob' && job_wrapper['arguments']&.first == campaign_id
          job.delete
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to clear Sidekiq jobs for campaign #{campaign_id}: #{e.message}")
  end
end
