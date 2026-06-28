# frozen_string_literal: true

class Public::Api::V1::AccountFormsController < PublicController
  before_action :set_account_form

  def show
    if @account_form.paused?
      render json: { error: 'form_paused', message: I18n.t('account_forms.public.paused') }, status: :forbidden
      return
    end

    unless @account_form.published?
      render json: { error: 'form_unavailable' }, status: :not_found
      return
    end
  end

  def submit
    if params[:website_token].present? && params[:website_token] != honeypot_token
      render json: { success: true }, status: :ok
      return
    end

    result = AccountForms::SubmitService.new(
      account_form: @account_form,
      params: submission_params,
      request_meta: {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    ).perform

    if result[:success]
      render json: {
        success: true,
        message: @account_form.settings['confirmation_message']
      }, status: :created
    else
      render json: {
        error: result[:error],
        message: I18n.t("account_forms.errors.#{result[:error]}", default: result[:error])
      }, status: :unprocessable_entity
    end
  end

  private

  def set_account_form
    account = Account.find(params[:account_id])
    @account_form = account.account_forms.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'form_not_found' }, status: :not_found
  end

  def submission_params
    # Base keys always permitted; dynamic field keys whitelisted from the form definition
    static_keys = %i[name email phone_number website_token
                     utm_source utm_medium utm_campaign utm_term utm_content]
    dynamic_keys = dynamic_field_keys
    params.permit(*static_keys, *dynamic_keys)
  end

  def dynamic_field_keys
    return [] unless @account_form

    @account_form.definition.fetch('fields', []).filter_map do |field|
      key = field['key'].presence
      next if key.blank?
      # Avoid re-permitting already-static keys
      %w[name email phone_number].include?(key) ? nil : key.to_sym
    end
  end

  def honeypot_token
    'hidden'
  end
end
