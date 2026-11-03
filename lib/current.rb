module Current
  thread_mattr_accessor :user
  thread_mattr_accessor :account
  thread_mattr_accessor :account_user
  thread_mattr_accessor :executed_by
  thread_mattr_accessor :contact
  thread_mattr_accessor :skip_workflow_triggers
  thread_mattr_accessor :skip_kanban_ownership_sync

  def self.reset
    Current.user = nil
    Current.account = nil
    Current.account_user = nil
    Current.executed_by = nil
    Current.contact = nil
    Current.skip_workflow_triggers = nil
    Current.skip_kanban_ownership_sync = nil
  end
end
