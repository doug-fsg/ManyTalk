# frozen_string_literal: true

class Contacts::KanbanConversationAssigneesPreloader
  def initialize(account, contacts)
    @account = account
    @contacts = Array(contacts)
  end

  def by_position_id
    return {} if @contacts.empty?

    positions = @contacts.flat_map { |contact| contact.contact_pipeline_positions.to_a }
    return {} if positions.empty?

    conversations_by_contact = load_conversations(positions).group_by(&:contact_id)
    selected_by_position = positions.each_with_object({}) do |position, memo|
      memo[position.id] = pick_conversation(position, conversations_by_contact[position.contact_id] || [])
    end
    preload_assignees(selected_by_position.values.compact)

    selected_by_position.each_with_object({}) do |(position_id, conversation), hash|
      assignee = conversation&.assignee
      next unless assignee

      hash[position_id] = {
        id: assignee.id,
        name: assignee.name,
        available_name: assignee.available_name,
        avatar_url: assignee.try(:avatar_url),
        thumbnail: assignee.try(:avatar_url)
      }
    end
  end

  private

  def load_conversations(positions)
    Conversation.where(
      account_id: @account.id,
      contact_id: positions.map(&:contact_id).uniq,
      status: [Conversation.statuses[:open], Conversation.statuses[:pending]]
    ).order(last_activity_at: :desc)
  end

  def preload_assignees(conversations)
    assigned = conversations.select(&:assignee_id).uniq
    return if assigned.empty?

    ActiveRecord::Associations::Preloader.new(
      records: assigned,
      associations: { assignee: [:account_users, { avatar_attachment: [:blob] }] }
    ).call
  end

  def pick_conversation(position, conversations)
    stored_id = position.metadata.is_a?(Hash) ? position.metadata['primary_conversation_id'] : nil
    if stored_id.present?
      match = conversations.find { |item| item.display_id == stored_id.to_i || item.id == stored_id.to_i }
      return match if match
    end

    conversations.first
  end
end
