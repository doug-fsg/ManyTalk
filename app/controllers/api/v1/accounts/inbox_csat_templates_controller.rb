class Api::V1::Accounts::InboxCsatTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def show
    service = CsatTemplateManagementService.new(@inbox)
    result = service.template_status

    if result[:service_error]
      render json: { error: result[:service_error] }, status: :internal_server_error
    else
      render json: result
    end
  end

  def create
    template_params = extract_template_params
    return render_missing_message_error if template_params[:message].blank?

    service = CsatTemplateManagementService.new(@inbox)
    result = service.create_template(template_params)
    render_template_creation_result(result)
  rescue ActionController::ParameterMissing
    render json: { error: 'Template parameters are required' }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, action_name == 'create' ? :update? : :show?
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'CSAT template operations only available for WhatsApp Cloud channels' },
           status: :bad_request
  end

  def extract_template_params
    params.require(:template).permit(:message, :button_text, :language)
  end

  def render_missing_message_error
    render json: { error: 'Message is required' }, status: :unprocessable_entity
  end

  def render_template_creation_result(result)
    if result[:success]
      render json: {
        template: {
          name: result[:template_name],
          template_id: result[:template_id],
          status: 'PENDING',
          language: result[:language] || 'en'
        }
      }, status: :created
    elsif result[:service_error]
      render json: { error: result[:service_error] }, status: :internal_server_error
    else
      error_message = parse_whatsapp_error(result[:response_body]) || result[:error]
      render json: { error: error_message }, status: :unprocessable_entity
    end
  end

  def parse_whatsapp_error(response_body)
    return if response_body.blank?

    error_data = JSON.parse(response_body)
    whatsapp_error = error_data['error'] || {}
    whatsapp_error['error_user_msg'] || whatsapp_error['message']
  rescue JSON::ParserError
    nil
  end
end
