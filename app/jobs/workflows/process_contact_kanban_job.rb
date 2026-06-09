# frozen_string_literal: true

module Workflows
  class ProcessContactKanbanJob < ApplicationJob
    queue_as :medium

    def perform(account_id, contact_id, pipeline_id, stage_id, previous_stage_id)
      Workflows::OrchestratorService.on_contact_kanban_stage_changed(
        account_id: account_id,
        contact_id: contact_id,
        pipeline_id: pipeline_id,
        stage_id: stage_id,
        previous_stage_id: previous_stage_id
      )
    end
  end
end
