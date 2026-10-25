class Contacts::KanbanLabelsPreloader
  def initialize(account, contact_ids)
    @account = account
    @contact_ids = Array(contact_ids).compact.uniq
  end

  def labels_by_contact_id
    return {} if @contact_ids.empty?

    titles_by_contact = Hash.new { |hash, key| hash[key] = Set.new }
    collect_contact_tag_names(titles_by_contact)
    collect_conversation_cached_names(titles_by_contact)

    labels_by_title = account_labels_by_title(titles_by_contact.values.flat_map(&:to_a).uniq)

    titles_by_contact.transform_values do |titles|
      titles.filter_map do |title|
        record = labels_by_title[title.to_s.downcase]
        next unless record

        { id: record.id, title: record.title, color: record.color }
      end
    end
  end

  private

  def collect_contact_tag_names(titles_by_contact)
    ActsAsTaggableOn::Tagging
      .joins(:tag)
      .where(taggable_type: 'Contact', taggable_id: @contact_ids)
      .pluck(:taggable_id, 'tags.name')
      .each { |contact_id, name| titles_by_contact[contact_id] << name if name.present? }
  end

  # cached_label_list evita JOIN em taggings por conversa na serialização do board.
  def collect_conversation_cached_names(titles_by_contact)
    Conversation
      .where(account_id: @account.id, contact_id: @contact_ids)
      .where.not(cached_label_list: [nil, ''])
      .pluck(:contact_id, :cached_label_list)
      .each do |contact_id, list|
        list.to_s.split(',').each do |title|
          stripped = title.strip
          titles_by_contact[contact_id] << stripped if stripped.present?
        end
      end
  end

  def account_labels_by_title(titles)
    downcased = titles.map { |title| title.to_s.downcase }.uniq
    return {} if downcased.empty?

    @account.labels.where('LOWER(title) IN (?)', downcased).index_by { |label| label.title.downcase }
  end
end
