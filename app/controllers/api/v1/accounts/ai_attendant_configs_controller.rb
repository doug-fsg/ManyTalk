# frozen_string_literal: true

class Api::V1::Accounts::AiAttendantConfigsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: :import
  before_action :fetch_ai_attendant_config, only: [:show, :update, :destroy, :test]

  def index
    @ai_attendant_configs = Current.account.ai_attendant_configs
                                   .includes(:ai_attendant_config_inboxes, reference_files_attachments: :blob)
  end

  def show; end

  def create
    @ai_attendant_config = Current.account.ai_attendant_configs.new(config_params)
    ActiveRecord::Base.transaction do
      @ai_attendant_config.save!
      sync_inbox_links!(@ai_attendant_config)
      assign_sender_user!
    end
    sync_reference_files
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: inbox_link_error_message(e.record) }, status: :unprocessable_entity
  end

  def update
    ActiveRecord::Base.transaction do
      @ai_attendant_config.update!(config_params)
      sync_inbox_links!(@ai_attendant_config) if inbox_ids_param_present?
      assign_sender_user!
    end
    @ai_attendant_config.reload
    sync_reference_files
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: inbox_link_error_message(e.record) }, status: :unprocessable_entity
  end

  def destroy
    @ai_attendant_config.destroy!
    head :ok
  end

  def import
    @ai_attendant_config = AiAttendant::ImportFromManyIa.call(
      account: Current.account,
      payload: import_payload
    )
    render :create
  rescue AiAttendant::ImportFromManyIa::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def test
    system = AiAttendant::PromptBuilder.build_system(
      config: @ai_attendant_config,
      conversation: sandbox_conversation
    )
    user = AiAttendant::PromptBuilder.build_user(
      config: @ai_attendant_config,
      combined_text: params.require(:message),
      at: Time.current
    )

    result = AiAttendant::ChatService.new(
      conversation: sandbox_conversation,
      config: @ai_attendant_config,
      system: system,
      user: user,
      history: test_history_param,
      sandbox: true
    ).perform

    render json: {
      reply: result[:text],
      handoff: result[:handoff],
      messages: AiAttendant::ReplyBlocks.as_json(result[:text], @ai_attendant_config)
    }
  end

  private

  def import_payload
    params.to_unsafe_h.except('controller', 'action', 'account_id', 'format')
  end

  def fetch_ai_attendant_config
    scoped = Current.account.ai_attendant_configs
    scoped = scoped.includes(:ai_attendant_config_inboxes, reference_files_attachments: :blob) if %w[show test].include?(action_name)
    @ai_attendant_config = if params[:inbox_id].present? && action_name == 'show'
                             scoped.for_inbox(params[:inbox_id]).first!
                           else
                             scoped.find(params[:id])
                           end
  end

  def test_history_param
    raw = params[:history]
    return [] if raw.blank?

    Array(raw).filter_map do |entry|
      role = entry[:role] || entry['role']
      content = entry[:content] || entry['content']
      next unless %w[user assistant].include?(role.to_s)
      next if content.blank?

      { role: role.to_s, content: content.to_s }
    end
  end

  def assign_sender_user!
    @ai_attendant_config.sender_user = AiAttendant::EnsureSenderUser.for(config: @ai_attendant_config)
    @ai_attendant_config.save! if @ai_attendant_config.sender_user_id_changed?
  end

  def sandbox_conversation
    inbox = @ai_attendant_config.inboxes.first
    Conversation.new(account: Current.account, inbox: inbox)
  end

  def sync_inbox_links!(config)
    ids = resolved_inbox_ids_param
    raise inbox_link_invalid!(config, 'Selecione ao menos uma caixa de entrada.') if ids.empty?

    owned_ids = Current.account.inboxes.where(id: ids).pluck(:id)
    if owned_ids.size != ids.size
      raise inbox_link_invalid!(config, 'Caixa de entrada inválida para esta conta.')
    end

    conflict = AiAttendantConfigInbox
               .where(inbox_id: ids)
               .where.not(ai_attendant_config_id: config.id)
               .joins(:ai_attendant_config)
               .where(ai_attendant_configs: { account_id: Current.account.id })
    if conflict.exists?
      raise inbox_link_invalid!(config, 'Uma ou mais caixas já estão vinculadas a outro atendente IA.')
    end

    config.ai_attendant_config_inboxes.where.not(inbox_id: ids).destroy_all
    missing = ids - config.ai_attendant_config_inboxes.pluck(:inbox_id)
    missing.each { |inbox_id| config.ai_attendant_config_inboxes.create!(inbox_id: inbox_id) }
    config.reload
  end

  def inbox_link_invalid!(config, message)
    config.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, config
  end

  def inbox_link_error_message(record)
    record.errors.full_messages.to_sentence.presence || record.errors.generate_message(:base, :invalid)
  end

  def inbox_ids_param_present?
    params.key?(:inbox_ids) ||
      params.key?(:inbox_id) ||
      params.dig(:ai_attendant_config, :inbox_ids).present? ||
      params.dig(:ai_attendant_config, :inbox_id).present?
  end

  def resolved_inbox_ids_param
    ids = integer_ids_from(inbox_ids_param)
    return ids if ids.any?

    single = params[:inbox_id].presence || params.dig(:ai_attendant_config, :inbox_id)
    single.present? ? [Integer(single)] : []
  end

  def inbox_ids_param
    params[:inbox_ids].presence || params.dig(:ai_attendant_config, :inbox_ids)
  end

  def sync_reference_files
    purge_reference_files
    attach_reference_files
    @ai_attendant_config.reload
    rename_reference_files
  end

  def attach_reference_files
    ids = integer_ids_from(file_sync_param(:reference_file_blob_ids))
    return if ids.empty?

    existing = @ai_attendant_config.reference_files.map(&:blob_id)
    (ids - existing).each do |blob_id|
      blob = ActiveStorage::Blob.find_by(id: blob_id)
      @ai_attendant_config.reference_files.attach(blob) if blob.present?
    end
  end

  def rename_reference_files
    names_by_blob = string_map_from(file_sync_param(:reference_file_names))
    names_by_attachment = string_map_from(file_sync_param(:reference_file_attachment_names))
    return if names_by_blob.empty? && names_by_attachment.empty?

    @ai_attendant_config.reference_files.each do |file|
      key = names_by_attachment[file.id.to_s].presence || names_by_blob[file.blob_id.to_s]
      rename_blob_to_key(file.blob, key)
    end
  end

  def rename_blob_to_key(blob, key)
    slug = reference_file_slug(key)
    return if slug.blank? || blob.blank?

    extension = File.extname(blob.filename.to_s)
    next_name = "#{slug}#{extension}"
    blob.update!(filename: next_name) unless blob.filename.to_s == next_name
  end

  def reference_file_slug(value)
    parameterized = value.to_s.parameterize
    parameterized = parameterized[0, 24]
    return if parameterized.blank? || parameterized.length < 2

    parameterized
  end

  def string_map_from(raw)
    hash = case raw
           when ActionController::Parameters then raw.to_unsafe_h
           when Hash then raw
           else {}
           end
    hash.each_with_object({}) do |(id, name), acc|
      slug = reference_file_slug(name)
      acc[id.to_s] = slug if slug.present?
    end
  end

  def purge_reference_files
    ids = integer_ids_from(file_sync_param(:remove_reference_file_ids))
    return if ids.empty?

    @ai_attendant_config.reference_files.each do |file|
      file.purge if ids.include?(file.id)
    end
  end

  def file_sync_param(key)
    value = params[key]
    return value if value.present?

    source = params[:ai_attendant_config]
    source.present? ? source[key] : nil
  end

  def integer_ids_from(raw)
    Array(raw).filter_map do |value|
      Integer(value.to_s, exception: false)
    end.uniq
  end

  def config_params
    permitted = config_param_source.permit(
      :avatar_id,
      :active,
      :pause_reason,
      :digital_agent_name,
      :agent_role,
      :agent_duties,
      :agent_objective,
      :company_context,
      :handoff_conditions,
      :handoff_customer_message,
      :schedule_mode,
      :detect_language,
      :debounce_seconds,
      :many_ia_config_id,
      :behavior_step_mode,
      behavior_steps: %i[instruction completion_criterion],
      topics_to_avoid: []
    )
    permitted.except(:account_id, :sender_user_id)
  end

  def config_param_source
    if params[:ai_attendant_config].present?
      params.require(:ai_attendant_config)
    else
      params
    end
  end
end
