class Api::OneoffApiCampaignService
  pattr_initialize [:campaign!]

  BATCH_SIZE = 50
  WEBHOOK_URL = ENV.fetch('WEBHOOK_URL_CAMPANHA', nil)

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'API' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!

    # Filtra os IDs das labels e os contatos da audiência
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    audience_contacts = campaign.audience.select { |audience| audience['type'] == 'Contact' }

    # Processa as labels e os contatos
    audience_labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)
    process_audience_labels(audience_labels)
    process_audience_contacts(audience_contacts)
  end

  private

  # Processa os contatos associados às labels através do banco de dados
  def process_audience_labels(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    process_contacts(contacts)
  end

  # Processa os contatos diretamente se o tipo for 'Contact', sem consultar o banco de dados
  def process_audience_contacts(audience_contacts)
    # Para os contatos que vêm diretamente da audiência, apenas os processa
    process_contacts(audience_contacts)
  end

  # Processa os contatos, seja eles da audiência diretamente ou da consulta
  def process_contacts(contacts)
    contacts.each_slice(BATCH_SIZE) do |batch|
      send_webhook(batch)
    end
  end

  # Envia os dados ao webhook
  def send_webhook(contacts)
    payload = {
      campaign_id: campaign.id,
      message: campaign.message,
      inbox: campaign.inbox.id,
      account: campaign.account.id,
      account_name: campaign.account.name,
      macros: campaign.trigger_rules,
      contacts: contacts.map { |contact| contact_payload(contact) }
    }

    response = HTTParty.post(
      WEBHOOK_URL,
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      Rails.logger.info("Webhook sent successfully for campaign #{campaign.id} with #{contacts.size} contacts")
    else
      Rails.logger.error("Failed to send webhook for campaign #{campaign.id}. Error: #{response.body}")
    end
  rescue StandardError => e
    Rails.logger.error("Error sending webhook for campaign #{campaign.id}. Error: #{e.message}")
  end

  # Monta o payload de contato, seja do banco de dados ou diretamente da audiência
  def contact_payload(contact)
    if contact.is_a?(Hash) # Se vier diretamente da audiência
      {
        type: 'contact',
        name: contact['name'],
        email: contact['email'],
        phone_number: contact['phone_number'],
        identifier: contact['id']
      }
    else # Se vier do banco de dados
      {
        type: 'label',
        id: contact.id,
        name: contact.name,
        email: contact.email,
        phone_number: contact.phone_number
      }
    end
  end
end
