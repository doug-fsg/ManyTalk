# frozen_string_literal: true

module Conversations
  # Finds an open conversation on a contact inbox that the acting agent can reuse
  # instead of starting a duplicate thread.
  #
  # Reuse when the conversation is unassigned or already assigned to the actor.
  # Skip when it is assigned to another agent (caller should create a new conversation).
  class ReusableConversationFinder
    pattr_initialize [:contact_inbox!, :actor!]

    def find
      contact_inbox.conversations.open
                   .where(assignee_id: [nil, actor.id])
                   .order(updated_at: :desc)
                   .first
    end
  end
end
