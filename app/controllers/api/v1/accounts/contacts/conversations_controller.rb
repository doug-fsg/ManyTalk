class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  def index
    @conversations = conversations_for_contact
  end

  private

  def conversations_for_contact
    conversations = Current.account.conversations
                           .where(inbox_id: inbox_ids, contact_id: @contact.id)
                           .order(id: :desc)
                           .limit(20)
                           .preload(
                             :inbox,
                             :team,
                             :contact_inbox,
                             { contact: { avatar_attachment: [:blob] } }
                           )
                           .to_a

    preload_assignees(conversations)
    conversations
  end

  # Só pré-carrega assignee nas conversas que têm atendente — senão o Bullet
  # marca o include como unused nas conversas sem assignee.
  def preload_assignees(conversations)
    assigned = conversations.select(&:assignee_id)
    return if assigned.empty?

    ActiveRecord::Associations::Preloader.new(
      records: assigned,
      associations: { assignee: [:account_users, { avatar_attachment: [:blob] }] }
    ).call
  end

  def inbox_ids
    if Current.user.administrator? || Current.user.agent?
      Current.user.assigned_inboxes.pluck(:id)
    else
      []
    end
  end
end
