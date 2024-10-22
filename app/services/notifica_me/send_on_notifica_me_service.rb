class NotificaMe::SendOnNotificaMeService < Base::SendOnChannelService
  private

  def channel_class
    Channel::NotificaMe
  end

  def perform_reply
    url = "https://hub.notificame.com.br/v1/channels/#{channel.notifica_me_path}/messages"
    body = message_params.to_json
    Rails.logger.debug { "NotificaMe message params #{body}" }
    response = HTTParty.post(
      url,
      body: body,
      headers: {
        'X-API-Token' => channel.notifica_me_token,
        'Content-Type' => 'application/json'
      },
      format: :json
    )
    Rails.logger.debug { "Response from NotificaMe #{response}" }
    raise "Error on send mensagem to NotificaMe: #{response['code']} -> #{response['message']}" unless response.success?

    message.update!(source_id: response.parsed_response['id'])
  rescue StandardError => e
    Rails.logger.error('Error on send do NotificaMe')
    Rails.logger.error(e)
    message.update!(status: :failed, external_error: e.to_s)
  end

  def message_params
    contents = message.attachments.length.positive? ? message_params_media : message_params_text
    {
      from: channel.notifica_me_id,
      to: contact_inbox.source_id,
      contents: contents
    }
  end

  def message_params_text
    [
      {
        type: :text,
        text: message.content || ''
      }
    ]
  end

  def message_params_media
    message.attachments.map do |a|
      file_type = file_type(a)
      data = {
        type: :file,
        fileMimeType: file_type,
        fileUrl: a.download_url
      }
      data[:fileCaption] = message.content if message.content

      data
    end
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end

  def file_type(attachment)
    if attachment.file_type == 'image'
      return 'photo' if channel.notifica_me_type == 'telegram'
    elsif attachment.file_type == 'file'
      extension = extension(attachment.download_url)
      if %w[pdf doc docx xls xlsx ppt pptx odt csv txt].include?(extension)
        return 'document'
      elsif attachment.file_type == 'file' && %w[mov mp4].include?(extension)
        return 'video'
      elsif attachment.file_type == 'file' && %w[ogg mp3 wav].include?(extension)
        return 'audio'
      end
    end
    attachment.file_type
  end

  def extension(url)
    url.match(/\.(\w+)$/)&.captures&.first
  end
end