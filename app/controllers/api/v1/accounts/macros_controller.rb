class Api::V1::Accounts::MacrosController < Api::V1::Accounts::BaseController
  before_action :fetch_macro, only: [:show, :update, :destroy, :execute]
  before_action :ensure_macro_present, only: [:show, :update, :destroy, :execute]
  before_action :check_authorization, only: [:show, :update, :destroy, :execute]

  def index
    @macros = Macro.with_visibility(current_user, params)
  end

  def show; end

  def create
    @macro = Current.account.macros.new(macros_with_user.merge(created_by_id: current_user.id))
    @macro.set_visibility(current_user, permitted_params)
    @macro.actions = params[:actions]

    render json: { error: @macro.errors.messages }, status: :unprocessable_entity and return unless @macro.valid?

    @macro.save!
    process_attachments
    @macro
  end

  def update
    ActiveRecord::Base.transaction do
      @macro.update!(macros_with_user)
      @macro.set_visibility(current_user, permitted_params)
      process_attachments
      @macro.save!
    rescue StandardError => e
      Rails.logger.error e
      render json: { error: @macro.errors.messages }.to_json, status: :unprocessable_entity
    end
  end

  def destroy
    @macro.destroy!
    head :ok
  end

  def execute
    ::MacrosExecutionJob.perform_now(
      @macro,
      conversation_ids: params[:conversation_ids],
      user: Current.user,
      raise_on_error: true
    )

    head :ok
  rescue StandardError => e
    Rails.logger.error("[MacrosController#execute] #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def process_attachments
    actions = @macro.actions.filter_map { |action| action if action['action_name'] == 'send_attachment' }
    return if actions.blank?

    blob_ids = actions.flat_map { |action| Array.wrap(action['action_params']).flatten.compact }.uniq
    @macro.files.purge

    blob_ids.each do |blob_id|
      blob = ActiveStorage::Blob.find_by(id: blob_id)
      @macro.files.attach(blob) if blob.present?
    end
  end

  def permitted_params
    params.permit(
      :name, :visibility,
      actions: [:action_name, { action_params: [] }]
    )
  end

  def ensure_macro_present
    head :not_found if @macro.nil?
  end

  def macros_with_user
    permitted_params.merge(updated_by_id: current_user.id)
  end

  def fetch_macro
    @macro = Current.account.macros.find_by(id: params[:id])
  end

  def check_authorization
    authorize(@macro) if @macro.present?
  end
end
