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
    if @account_form.paused?
      render json: { error: 'form_paused', message: I18n.t('account_forms.public.paused') }, status: :forbidden
      return
    end

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
    static_keys = %i[name email phone_number website_token
                     utm_source utm_medium utm_campaign utm_term utm_content]
    dynamic_keys = dynamic_field_keys
    permitted_keys = static_keys + dynamic_keys

    source = submission_param_source
    source.permit(*permitted_keys)
  end

  def submission_param_source
    return params if submission_payload_present?(params)

    json_source = json_body_params
    return json_source if submission_payload_present?(json_source)

    params
  end

  def json_body_params
    body = request.body.read
    request.body.rewind
    return ActionController::Parameters.new({}) if body.blank?

    parsed = JSON.parse(body)
    parsed = parsed['_json'] if parsed.is_a?(Hash) && parsed['_json'].is_a?(Hash)
    ActionController::Parameters.new(parsed)
  rescue JSON::ParserError
    ActionController::Parameters.new({})
  end

  def submission_payload_present?(source)
    return false unless source.respond_to?(:to_unsafe_h)

    ignored = %w[website_token controller action account_id slug format]
    source.to_unsafe_h.except(*ignored).values.any?(&:present?)
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
