# frozen_string_literal: true

module Workflows
  class KanbanIdleCheckJob < ApplicationJob
    queue_as :low

    def perform
      Account.find_each do |account|
        next unless account.feature_enabled?('workflows')

        process_account(account)
      end
    end

    private

    def process_account(account)
      workflows = account.workflows.for_trigger_event('contact_kanban_stage_idle').active
      return if workflows.empty?

      workflows.each do |workflow|
        idle_days = workflow.trigger_node&.dig('data', 'idle_days').to_i
        next if idle_days <= 0

        pipeline_id = workflow.trigger_node&.dig('data', 'pipeline_id')
        stage_id = workflow.trigger_node&.dig('data', 'stage_id')
        next if pipeline_id.blank? || stage_id.blank?

        cutoff = idle_days.days.ago
        positions = ContactPipelinePosition.for_account(account.id)
                                           .for_pipeline(pipeline_id)
                                           .for_stage(stage_id)
                                           .where('entered_at <= ?', cutoff)

        positions.find_each do |position|
          trigger_for_position(workflow, account, position)
        end
      end
    end

    def trigger_for_position(workflow, account, position)
      conversation = position.contact.conversations.open.order(updated_at: :desc).first
      return if conversation.blank?
      return if OrchestratorService.enrollment_exists?(workflow, conversation)

      Workflows::OrchestratorService.on_event(
        event_name: 'contact_kanban_stage_idle',
        account_id: account.id,
        conversation_id: conversation.id,
        changed_attributes: {
          'pipeline_id' => [nil, position.pipeline_id.to_s],
          'stage_id' => [nil, position.stage_id]
        }
      )
    end
  end
end
