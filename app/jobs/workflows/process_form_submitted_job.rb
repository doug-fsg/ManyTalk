# frozen_string_literal: true

module Workflows
  class ProcessFormSubmittedJob < ApplicationJob
    queue_as :medium

    def perform(account_id, contact_id, account_form_id, submission_id)
      AccountForms::WorkflowTriggerService.call(
        account_id: account_id,
        contact_id: contact_id,
        account_form_id: account_form_id,
        submission_id: submission_id
      )
    end
  end
end
