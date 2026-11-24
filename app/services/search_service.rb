class SearchService
  pattr_initialize [:current_user!, :current_account!, :params!, :search_type!]

  RESULTS_LIMIT = 10
  MESSAGE_LOOKBACK = 3.months

  def perform
    case search_type
    when 'Message'
      { messages: filter_messages }
    when 'Conversation'
      { conversations: filter_conversations }
    when 'Contact'
      { contacts: filter_contacts }
    else
      { contacts: filter_contacts, messages: filter_messages, conversations: filter_conversations }
    end
  end

  private

  def accessable_inbox_ids
    @accessable_inbox_ids ||= @current_user.assigned_inboxes.pluck(:id)
  end

  def search_query
    @search_query ||= params[:q].to_s.strip
  end

  def like_search_query
    ActiveRecord::Base.sanitize_sql_like(search_query)
  end

  def filter_conversations
    return Conversation.none if search_query.blank?

    @conversations = current_account.conversations.where(inbox_id: accessable_inbox_ids)
                                    .joins('INNER JOIN contacts ON conversations.contact_id = contacts.id')
                                    .where("cast(conversations.display_id as text) ILIKE :search OR contacts.name ILIKE :search OR contacts.email
                            ILIKE :search OR contacts.phone_number ILIKE :search OR contacts.identifier ILIKE :search", search: "%#{like_search_query}%")
                                    .order('conversations.created_at DESC')
                                    .limit(RESULTS_LIMIT)
  end

  def filter_messages
    return Message.none if search_query.blank?

    @messages = if use_gin_search
                  filter_messages_with_gin
                else
                  filter_messages_with_like
                end
  end

  def filter_messages_with_like
    message_base_query
      .where('messages.content ILIKE :search', search: "%#{like_search_query}%")
      .reorder('messages.created_at DESC, messages.id DESC')
      .limit(RESULTS_LIMIT)
  end

  def filter_messages_with_gin
    tsquery = gin_tsquery
    return filter_messages_with_like if tsquery.blank?

    message_base_query
      .where('content @@ to_tsquery(?)', tsquery)
      .reorder('messages.created_at DESC, messages.id DESC')
      .limit(RESULTS_LIMIT)
  rescue ActiveRecord::StatementInvalid
    filter_messages_with_like
  end

  def gin_tsquery
    terms = search_query.split.filter_map { |term| term.gsub(/[^[:alnum:]]/, '').presence }
    terms.join(' <-> ').presence
  end

  # Recorta por created_at antes do ILIKE para o planner usar
  # index_messages_on_account_created_type em contas com alto volume.
  def message_base_query
    current_account.messages
                   .where('messages.created_at >= ?', MESSAGE_LOOKBACK.ago)
                   .where(inbox_id: accessable_inbox_ids)
  end

  def use_gin_search
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('MESSAGE_SEARCH_USE_GIN', false))
  end

  def filter_contacts
    return Contact.none if search_query.blank?

    @contacts = current_account.contacts.where(
      "name ILIKE :search OR email ILIKE :search OR phone_number
      ILIKE :search OR identifier ILIKE :search", search: "%#{like_search_query}%"
    ).resolved_contacts.order_on_last_activity_at('desc').limit(RESULTS_LIMIT)
  end
end
