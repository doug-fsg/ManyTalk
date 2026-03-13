# frozen_string_literal: true

class Api::V1::Accounts::WhatsappWebConnectionsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :check_whatsapp_web_inbox
  before_action :check_webhook_url

  def create
    webhook_url = ENV.fetch('WEBHOOK_URL', nil)
    webhook_response = HTTParty.post(
      webhook_url,
      body: connection_params.to_json,
      headers: {
        'Content-Type' => 'application/json'
      },
      timeout: 30
    )

    handle_response(webhook_response)
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web connection error: #{e.message}"
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def check_whatsapp_web_inbox
    return if @inbox.api? && @inbox.channel.try(:additional_attributes)&.dig('source') == 'whatsapp_web'

    render json: { message: 'Invalid inbox type' }, status: :forbidden
  end

  def check_webhook_url
    return if ENV.fetch('WEBHOOK_URL', nil).present?

    render json: { message: 'WEBHOOK_URL not configured in .env' }, status: :unprocessable_entity
  end

  def connection_params
    {
      event: params[:event],
      enableGroup: params[:enableGroup],
      enableAgentName: params[:enableAgentName],
      timestamp: params[:timestamp] || Time.current.iso8601,
      currentUser: current_user_data,
      accountId: Current.account.id,
      account: account_data,
      inbox: inbox_data
    }
  end

  def current_user_data
    return {} unless Current.user

    {
      id: Current.user.id,
      name: Current.user.name,
      email: Current.user.email
    }
  end

  def account_data
    {
      id: Current.account.id,
      name: Current.account.name
    }
  end

  def inbox_data
    {
      id: @inbox.id,
      name: @inbox.name,
      channel_id: @inbox.channel_id,
      webhook_url: ENV.fetch('WEBHOOK_URL', nil)
    }
  end

  def handle_response(webhook_response)
    content_type = webhook_response.headers['content-type'] || 'application/json'

    if content_type.include?('image/')
      send_data webhook_response.body,
                type: content_type,
                disposition: 'inline'
    elsif webhook_response.success?
      response.headers['numero'] = webhook_response.headers['numero'] if webhook_response.headers['numero']
      response.headers['grupo'] = webhook_response.headers['grupo'] if webhook_response.headers['grupo']
      response.headers['name_agent'] = webhook_response.headers['name_agent'] if webhook_response.headers['name_agent']
      render json: (webhook_response.parsed_response || {}), status: webhook_response.code
    else
      render json: { message: webhook_response.body }, status: webhook_response.code
    end
  end
end
