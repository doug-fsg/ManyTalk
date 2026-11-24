class Channels::Whatsapp::TemplatesSyncJob < ApplicationJob
  queue_as :low

  def perform(whatsapp_channel)
    return if whatsapp_channel.reauthorization_required?

    whatsapp_channel.sync_templates
  end
end
