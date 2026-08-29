# frozen_string_literal: true

class Campaigns::AudienceResolver
  pattr_initialize [:campaign!]

  def deliverable_contacts
    deduplicate_by_phone(spreadsheet_contacts + label_contacts)
  end

  def deliverable_count
    deliverable_contacts.size
  end

  def each_deliverable_contact(&block)
    deliverable_contacts.each(&block)
  end

  def self.contact_phone_key(contact_data)
    phone = if contact_data.is_a?(Hash)
              contact_data['id'] || contact_data['phone_number']
            else
              contact_data.to_s
            end
    Contacts::BrazilPhoneNormalizer.canonical_lookup_key(phone).presence || phone.to_s.gsub(/\D/, '')
  end

  def self.normalize_job_contact(entry)
    return entry unless entry.is_a?(Hash)

    nested = entry['contact'] || entry[:contact]
    nested.presence || entry
  end

  private

  def spreadsheet_contacts
    campaign.audience.to_a.filter_map do |item|
      next unless item['type'] == 'Contact'
      next unless phone_from(item).present?

      item
    end
  end

  def label_contacts
    label_scope.filter_map do |contact|
      entry = label_contact_data(contact)
      phone_from(entry).present? ? entry : nil
    end
  end

  def label_contact_data(contact)
    {
      'type' => 'Label',
      'id' => contact.phone_number,
      'name' => contact.name,
      'db_id' => contact.id
    }
  end

  def label_scope
    ids = campaign.audience.to_a.select { |item| item['type'] == 'Label' }.map { |item| item['id'] }
    return Contact.none if ids.blank?

    labels = campaign.account.labels.where(id: ids).pluck(:title)
    return Contact.none if labels.blank?

    label_pattern = labels.map { |label| Regexp.escape(label) }.join('|')

    conversation_contact_ids = campaign.account.contacts
                                       .joins(:conversations)
                                       .merge(campaign.account.conversations.tagged_with(labels, any: true))
                                       .distinct
                                       .pluck('contacts.id')

    conversation_contact_ids |= campaign.account.contacts
                                        .joins(:conversations)
                                        .where('conversations.cached_label_list ~* ?', label_pattern)
                                        .distinct
                                        .pluck('contacts.id')

    contact_label_ids = campaign.account.contacts
                                .tagged_with(labels, any: true)
                                .pluck(:id)

    merged_ids = conversation_contact_ids | contact_label_ids
    return Contact.none if merged_ids.empty?

    campaign.account.contacts.where(id: merged_ids)
  end

  def phone_from(contact_data)
    contact_data.is_a?(Hash) ? (contact_data['id'] || contact_data['phone_number']) : contact_data.to_s
  end

  def deduplicate_by_phone(contacts)
    seen = {}
    contacts.select do |item|
      key = self.class.contact_phone_key(item)
      next false if key.blank? || seen[key]

      seen[key] = true
    end
  end
end
