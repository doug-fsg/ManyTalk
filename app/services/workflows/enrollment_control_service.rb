# frozen_string_literal: true

module Workflows
  class EnrollmentControlService
    def start(conversation:, workflow:, user:, start_node_id: nil)
      enrollment = conversation.account.workflow_enrollments.new(
        workflow: workflow,
        conversation: conversation,
        contact_id: conversation.contact_id,
        account: workflow.account,
        enrollment_scope: workflow.settings['enrollment_scope'] || 'contact',
        status: 'active',
        current_node_id: workflow.trigger_node&.dig('id'),
        started_at: Time.current,
        started_by: user
      )

      enrollment.save!
      EnrollmentBroadcaster.updated(enrollment)
      Workflows::ActivityLogger.log_started(conversation, workflow, user: user)

      trigger_id = workflow.trigger_node&.dig('id')
      start_id = start_node_id || trigger_id
      OrchestratorService.advance_from_node(workflow, enrollment, conversation, start_id)

      { enrollment: enrollment }
    rescue ActiveRecord::RecordNotUnique
      { error: :conflict, message: 'Active enrollment already exists for this workflow and conversation' }
    end

    def pause(enrollment:, user:, reason: 'manual')
      enrollment.with_lock do
        return { error: :invalid_transition } unless enrollment.may_pause?

        pending_execution = enrollment.workflow_step_executions.find_by(status: 'scheduled')
        enrollment.pause!(user: user, reason: reason)

        if pending_execution&.scheduled_at
          enrollment.update!(resume_at: pending_execution.scheduled_at)
        end

        JobScheduler.cancel_pending!(enrollment)
        EnrollmentBroadcaster.updated(enrollment)
        Workflows::ActivityLogger.log_paused(
          enrollment.conversation,
          enrollment.workflow,
          user: user,
          reason: reason
        )
        { enrollment: enrollment }
      end
    end

    def resume(enrollment:, user:)
      enrollment.with_lock do
        return { error: :invalid_transition } unless enrollment.may_resume?

        workflow = enrollment.workflow
        conversation = enrollment.conversation
        current_node = workflow.find_node(enrollment.current_node_id)

        if %w[wait wait_for_reply ai_wait_for_intent].include?(current_node&.dig('type'))
          delay = if enrollment.resume_at && enrollment.resume_at > Time.current
                    enrollment.resume_at - Time.current
                  else
                    1.second
                  end

          enrollment.resume_to_waiting!(resume_at: Time.current + delay)
          JobScheduler.schedule(enrollment, enrollment.current_node_id, delay)
        else
          enrollment.resume_to_active!
          OrchestratorService.advance_from_node(workflow, enrollment, conversation, enrollment.current_node_id)
        end

        EnrollmentBroadcaster.updated(enrollment)
        Workflows::ActivityLogger.log_resumed(conversation, workflow, user: user)
        { enrollment: enrollment }
      end
    end

    def cancel(enrollment:, user:, reason: 'manual')
      enrollment.with_lock do
        return { error: :invalid_transition } unless enrollment.may_cancel?

        JobScheduler.cancel_pending!(enrollment)
        enrollment.cancel!(reason)
        EnrollmentBroadcaster.updated(enrollment)
        Workflows::ActivityLogger.log_cancelled(
          enrollment.conversation,
          enrollment.workflow,
          user: user,
          reason: reason
        )
        { enrollment: enrollment }
      end
    end

    def jump_to_node(enrollment:, node_id:, user:)
      enrollment.with_lock do
        workflow = enrollment.workflow
        node = workflow.find_node(node_id)
        return { error: :node_not_found } if node.blank?

        JobScheduler.cancel_pending!(enrollment)

        enrollment.workflow_step_executions.where(status: 'scheduled').update_all(
          status: 'skipped', updated_at: Time.current
        )

        enrollment.update!(
          status: 'active',
          current_node_id: node_id,
          paused_at: nil,
          paused_by: nil,
          pause_reason: nil,
          resume_at: nil,
          context: (enrollment.context || {}).except('reply_watch', 'intent_watch')
        )

        conversation = enrollment.conversation
        OrchestratorService.advance_from_node(workflow, enrollment, conversation, node_id)

        EnrollmentBroadcaster.updated(enrollment.reload)
        { enrollment: enrollment }
      end
    end

    def handle_reply(enrollment, message = nil)
      if enrollment.intent_watch_active?
        return if message.present? && !enrollment.intent_matches_message?(message)
        return if skip_intent_enqueue?(enrollment, message)

        Workflows::IntentClassificationJob.perform_later(enrollment.id, message&.id)
        return
      end

      if enrollment.reply_watch_active?
        return if message.present? && !enrollment.reply_matches_message?(message)

        Workflows::OrchestratorService.on_contact_reply(enrollment)
        return
      end

      return if message.present? && !message.incoming?

      handle_contact_reply_side_effects(enrollment)
    end

    def handle_contact_reply(enrollment)
      handle_reply(enrollment, nil)
    end

    def skip_intent_enqueue?(enrollment, message)
      return true if enrollment.intent_watch_classification_in_flight?
      return true if message && enrollment.last_classified_message_id == message.id

      false
    end

    def handle_contact_reply_side_effects(enrollment)

      workflow = enrollment.workflow
      settings = workflow.settings

      if settings['pause_on_contact_reply'] != false
        pause(enrollment: enrollment, user: nil, reason: 'contact_replied')
      elsif WorkflowEnrollment.cancel_enabled?(workflow, 'contact_replied')
        cancel(enrollment: enrollment, user: nil, reason: 'contact_replied')
      end
    end
  end
end
