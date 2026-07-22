class MacrosExecutionJob < ApplicationJob
  queue_as :medium

  def perform(macro, conversation_ids:, user:, contact_data: nil, raise_on_error: false)
    account = macro.account
    conversations = account.conversations.where(display_id: conversation_ids.to_a)

    return if conversations.blank?

    conversations.each do |conversation|
      ::Macros::ExecutionService.new(macro, conversation, user, contact_data, raise_on_error: raise_on_error).perform
    end
  end
end
