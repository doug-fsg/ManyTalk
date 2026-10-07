# frozen_string_literal: true

module Workflows
  class ScheduleEnrollContactService
    def initialize(schedule:, contact_id:)
      @schedule = schedule
      @contact_id = contact_id
    end

    def perform
      return :inactive unless @schedule.workflow&.active?

      contact = @schedule.account.contacts.find_by(id: @contact_id)
      return :missing if contact.blank?
      return :left_stage unless still_on_stage?(contact)

      conversations = KanbanEnrollmentConversations.new(contact, workflow: @schedule.workflow)
                                                   .resolve_for(@schedule.workflow)
      return :no_conversation if conversations.blank?

      conversation = conversations.first
      return :skipped if EnrollmentPresence.exists?(@schedule.workflow, conversation)

      OrchestratorService.enroll_conversation(
        workflow: @schedule.workflow,
        conversation: conversation,
        event_name: 'recurring_schedule',
        changed_attributes: {
          'pipeline_id' => [nil, @schedule.pipeline_id.to_s],
          'stage_id' => [nil, @schedule.stage_id]
        }
      )
      :enrolled
    rescue ActiveRecord::RecordNotUnique
      :skipped
    end

    private

    def still_on_stage?(contact)
      ContactPipelinePosition.exists?(
        contact_id: contact.id,
        pipeline_id: @schedule.pipeline_id,
        stage_id: @schedule.stage_id
      )
    end
  end
end
