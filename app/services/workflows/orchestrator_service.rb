# frozen_string_literal: true

module Workflows
  class OrchestratorService
    class << self
      def on_event(event_name:, account_id:, conversation_id: nil, message_id: nil, changed_attributes: nil)
        account = Account.find_by(id: account_id)
        return if account.blank?
        return unless account.feature_enabled?('workflows')

        conversation = Conversation.find_by(id: conversation_id, account_id: account_id)
        return if conversation.blank?

        message = message_id.present? ? Message.find_by(id: message_id, account_id: account_id) : nil

        workflows = account.workflows.for_trigger_event(event_name).limit(Constants::MAX_WORKFLOWS_PER_EVENT)
        workflows.each do |workflow|
          next if workflow.settings['allow_manual_start_only']

          process_workflow_trigger(workflow, conversation, message, changed_attributes)
        end
      end

      def advance_from_node(workflow, enrollment, conversation, node_id)
        advance_from(workflow, enrollment, conversation, node_id, depth: 0)
      end

      def on_step(enrollment_id:, node_id:)
        enrollment = WorkflowEnrollment.find_by(id: enrollment_id)
        return if enrollment.blank? || enrollment.paused? || enrollment.cancelled? || enrollment.completed?
        return unless enrollment.may_run_step?(node_id)

        workflow = enrollment.workflow
        conversation = enrollment.conversation
        node = workflow.find_node(node_id)
        return if node.blank?

        enrollment.with_lock do
          return if enrollment.reload.cancelled?

          if enrollment.waiting?
            case node['type']
            when 'wait'
              resume_after_wait(workflow, enrollment, conversation, node)
            when 'wait_for_reply'
              resume_after_reply_timeout(workflow, enrollment, conversation, node)
            else
              process_node(workflow, enrollment, conversation, node)
            end
          else
            process_node(workflow, enrollment, conversation, node)
          end
        end
      end

      def on_contact_reply(enrollment)
        return unless enrollment.reply_watch_active?
        return unless enrollment.replied_since_baseline?

        workflow = enrollment.workflow
        conversation = enrollment.conversation

        enrollment.with_lock do
          enrollment.reload
          return unless enrollment.reply_watch_active?
          return unless enrollment.replied_since_baseline?

          node_id = enrollment.reply_watch['node_id']
          node = workflow.find_node(node_id)
          return if node.blank?

          JobScheduler.cancel_pending!(enrollment)
          mark_step_completed(enrollment, node_id)
          enrollment.clear_reply_watch!
          enrollment.update!(status: 'active')

          next_id = workflow.next_node_id(node_id, source_handle: 'replied')
          if next_id.blank?
            complete_enrollment(enrollment)
          else
            enrollment.update!(current_node_id: next_id)
            advance_from(workflow, enrollment, conversation, next_id, depth: 0)
          end
        end

        EnrollmentBroadcaster.updated(enrollment.reload)
      end

      def enrollment_exists?(workflow, conversation)
        active_enrollment_exists?(workflow, conversation)
      end

      def on_contact_kanban_stage_changed(account_id:, contact_id:, pipeline_id:, stage_id:, previous_stage_id:)
        account = Account.find_by(id: account_id)
        return if account.blank?
        return unless account.feature_enabled?('workflows')

        contact = account.contacts.find_by(id: contact_id)
        return if contact.blank?

        workflows = account.workflows.for_trigger_event('contact_kanban_stage_changed').limit(Constants::MAX_WORKFLOWS_PER_EVENT)
        return if workflows.empty?

        conversations = contact.conversations.open
        conversations = conversations.order(updated_at: :desc).limit(1)

        conversations.each do |conversation|
          workflows.each do |workflow|
            next if workflow.settings['allow_manual_start_only']

            process_workflow_trigger(workflow, conversation, nil, {
              'pipeline_id' => [nil, pipeline_id.to_s],
              'stage_id' => [previous_stage_id, stage_id]
            })
          end
        end
      end

      private

      def process_workflow_trigger(workflow, conversation, message, changed_attributes)
        return if skip_enrollment_for_older_conversation?(workflow, conversation)

        trigger = workflow.trigger_node
        return if trigger.blank?

        conditions = trigger.dig('data', 'conditions') || []
        return unless ConditionsEvaluator.new(
          account: workflow.account,
          conversation: conversation,
          conditions: conditions,
          message: message,
          changed_attributes: changed_attributes
        ).match?

        return if active_enrollment_exists?(workflow, conversation)

        begin
          enrollment = WorkflowEnrollment.create!(
            workflow: workflow,
            conversation: conversation,
            contact_id: conversation.contact_id,
            account: workflow.account,
            enrollment_scope: workflow.settings['enrollment_scope'] || 'contact',
            status: 'active',
            current_node_id: trigger['id'],
            started_at: Time.current
          )
        rescue ActiveRecord::RecordNotUnique
          Rails.logger.debug { "Workflow enrollment race skipped workflow=#{workflow.id} conversation=#{conversation.id}" }
          return
        end

        advance_from(workflow, enrollment, conversation, trigger['id'], depth: 0)
      end

      def active_enrollment_exists?(workflow, conversation)
        if workflow.settings['enrollment_scope'] == 'conversation'
          return WorkflowEnrollment.in_progress.exists?(workflow_id: workflow.id, conversation_id: conversation.id)
        end

        WorkflowEnrollment.in_progress.exists?(workflow_id: workflow.id, contact_id: conversation.contact_id)
      end

      def skip_enrollment_for_older_conversation?(workflow, conversation)
        return false unless workflow.settings['enroll_latest_conversation_only']

        contact = conversation.contact
        return false if contact.blank?

        latest = contact.conversations.open.order(updated_at: :desc).first
        latest.present? && latest.id != conversation.id
      end

      def advance_from(workflow, enrollment, conversation, node_id, depth: 0)
        node = workflow.find_node(node_id)
        return complete_enrollment(enrollment) if node.blank?

        case node['type']
        when 'trigger'
          move_to_next(workflow, enrollment, conversation, node_id, depth: depth)
        when 'action'
          execute_action(workflow, enrollment, conversation, node)
          move_to_next(workflow, enrollment, conversation, node_id, depth: depth)
        when 'ai_outreach'
          execute_ai_outreach(workflow, enrollment, conversation, node)
          move_to_next(workflow, enrollment, conversation, node_id, depth: depth)
        when 'ai_conversation_analysis'
          execute_ai_conversation_analysis(workflow, enrollment, conversation, node)
          move_to_next(workflow, enrollment, conversation, node_id, depth: depth)
        when 'wait'
          schedule_wait(workflow, enrollment, node)
        when 'wait_for_reply'
          schedule_reply_watch(workflow, enrollment, conversation, node)
        when 'condition'
          handle_condition(workflow, enrollment, conversation, node, depth: depth)
        else
          complete_enrollment(enrollment)
        end
      end

      def execute_action(workflow, enrollment, conversation, node)
        data = node['data'] || {}
        action_name = data['action_name']

        begin
          Current.skip_workflow_triggers = true if action_name == 'change_kanban_stage'
          Workflows::ActionService.new(
            workflow,
            workflow.account,
            conversation,
            node_id: node['id']
          ).perform_action(action_name, data['action_params'] || [])
        ensure
          Current.skip_workflow_triggers = nil
        end
      end

      def execute_ai_outreach(workflow, enrollment, conversation, node)
        Workflows::AiOutreachService.new(
          workflow: workflow,
          enrollment: enrollment,
          conversation: conversation,
          node: node
        ).perform!
      end

      def execute_ai_conversation_analysis(workflow, enrollment, conversation, node)
        Workflows::AiConversationAnalysisService.new(
          workflow: workflow,
          enrollment: enrollment,
          conversation: conversation,
          node: node
        ).perform!
      end

      def schedule_wait(workflow, enrollment, node)
        data = node['data'] || {}
        conversation = enrollment.conversation
        # Zero/nil duration schedules an immediate job; Sidekiq can run it before we set status to
        # `waiting`, so `on_step` hits `process_node` again instead of `resume_after_wait`. Enforce a
        # minimum delay and persist `waiting` before enqueueing.
        base_delay = wait_duration(data)
        scheduled_at = apply_business_hours(workflow, conversation, Time.current + base_delay)
        wait_delay = [scheduled_at - Time.current, 1.second].max

        execution = enrollment.workflow_step_executions.find_or_initialize_by(node_id: node['id'])
        return if execution.status == 'completed'

        enrollment.reload
        if execution.persisted? && execution.status == 'scheduled' && enrollment.waiting? && enrollment.current_node_id == node['id']
          return
        end

        ActiveRecord::Base.transaction do
          enrollment.update!(status: 'waiting', current_node_id: node['id'], resume_at: Time.current + wait_delay)
          execution.update!(
            status: 'scheduled',
            scheduled_at: Time.current + wait_delay,
            job_id: nil
          )
        end

        job = Workflows::StepJob.set(wait: wait_delay).perform_later(enrollment.id, node['id'])
        execution.update!(job_id: job&.provider_job_id)
      end

      def schedule_reply_watch(workflow, enrollment, conversation, node)
        data = node['data'] || {}
        base_delay = wait_duration(data)
        baseline_at = WorkflowEnrollment.reply_baseline_for(conversation)
        deadline_at = apply_business_hours(workflow, conversation, Time.current + base_delay)
        wait_delay = [deadline_at - Time.current, 1.second].max

        execution = enrollment.workflow_step_executions.find_or_initialize_by(node_id: node['id'])
        return if execution.status == 'completed'

        enrollment.reload
        if execution.persisted? && execution.status == 'scheduled' && enrollment.waiting? &&
           enrollment.current_node_id == node['id'] && enrollment.reply_watch_active?
          return
        end

        wait_responder = data['wait_responder'].presence || 'contact'

        ActiveRecord::Base.transaction do
          enrollment.set_reply_watch!(
            node_id: node['id'],
            baseline_at: baseline_at,
            deadline_at: deadline_at,
            wait_responder: wait_responder
          )
          enrollment.update!(
            status: 'waiting',
            current_node_id: node['id'],
            resume_at: deadline_at
          )
          execution.update!(
            status: 'scheduled',
            scheduled_at: deadline_at,
            job_id: nil
          )
        end

        job = Workflows::StepJob.set(wait: wait_delay).perform_later(enrollment.id, node['id'])
        execution.update!(job_id: job&.provider_job_id)
      end

      def apply_business_hours(workflow, conversation, time)
        return time if workflow.settings['respect_business_hours'] == false

        Workflows::BusinessHoursScheduler.new(conversation.inbox).adjust(time)
      end

      def wait_duration(data)
        duration = data['duration'].to_i
        unit = data['unit']
        case unit
        when 'minutes' then duration.minutes
        when 'hours' then duration.hours
        when 'days' then duration.days
        else duration.hours
        end
      end

      def handle_condition(workflow, enrollment, conversation, node, depth: 0)
        data = node['data'] || {}
        matched = ConditionsEvaluator.new(
          account: workflow.account,
          conversation: conversation,
          conditions: data['conditions'] || [],
          enrollment: enrollment
        ).match?
        handle = matched ? 'true' : 'false'
        next_id = workflow.next_node_id(node['id'], source_handle: handle)
        if next_id.blank?
          complete_enrollment(enrollment)
        else
          enrollment.update!(status: 'active', current_node_id: next_id)
          continue_to_node(workflow, enrollment, conversation, next_id, depth: depth)
        end
      end

      def move_to_next(workflow, enrollment, conversation, node_id, depth: 0)
        next_id = workflow.next_node_id(node_id)
        if next_id.blank?
          complete_enrollment(enrollment)
        else
          enrollment.update!(status: 'active', current_node_id: next_id)
          continue_to_node(workflow, enrollment, conversation, next_id, depth: depth)
        end
      end

      def continue_to_node(workflow, enrollment, conversation, node_id, depth: 0)
        if depth >= Constants::MAX_SYNC_ADVANCE_DEPTH
          Workflows::StepJob.perform_later(enrollment.id, node_id)
        else
          advance_from(workflow, enrollment, conversation, node_id, depth: depth + 1)
        end
      end

      def complete_enrollment(enrollment)
        enrollment.workflow_step_executions.where(node_id: enrollment.current_node_id, status: 'scheduled').update_all(
          status: 'completed',
          executed_at: Time.current
        )
        enrollment.complete!
      end

      def process_node(workflow, enrollment, conversation, node)
        mark_step_running(enrollment, node['id'])

        case node['type']
        when 'action'
          execute_action(workflow, enrollment, conversation, node)
          mark_step_completed(enrollment, node['id'])
          move_to_next(workflow, enrollment.reload, conversation, node['id'], depth: 0)
        when 'ai_outreach'
          execute_ai_outreach(workflow, enrollment, conversation, node)
          mark_step_completed(enrollment, node['id'])
          move_to_next(workflow, enrollment.reload, conversation, node['id'], depth: 0)
        when 'ai_conversation_analysis'
          execute_ai_conversation_analysis(workflow, enrollment, conversation, node)
          mark_step_completed(enrollment, node['id'])
          move_to_next(workflow, enrollment.reload, conversation, node['id'], depth: 0)
        when 'wait'
          schedule_wait(workflow, enrollment, node)
        when 'wait_for_reply'
          schedule_reply_watch(workflow, enrollment, conversation, node)
        when 'condition'
          handle_condition(workflow, enrollment, conversation, node, depth: 0)
        when 'trigger'
          move_to_next(workflow, enrollment, conversation, node['id'], depth: 0)
        else
          complete_enrollment(enrollment)
        end
      end

      def mark_step_running(enrollment, node_id)
        execution = enrollment.workflow_step_executions.find_or_create_by!(node_id: node_id)
        execution.update!(status: 'running') unless execution.status == 'completed'
      end

      def mark_step_completed(enrollment, node_id)
        execution = enrollment.workflow_step_executions.find_by(node_id: node_id)
        execution&.update!(status: 'completed', executed_at: Time.current)
      end

      def resume_after_wait(workflow, enrollment, conversation, node)
        mark_step_completed(enrollment, node['id'])
        enrollment.update!(status: 'active')
        move_to_next(workflow, enrollment, conversation, node['id'], depth: 0)
      end

      def resume_after_reply_timeout(workflow, enrollment, conversation, node)
        return unless enrollment.reply_watch_active?

        if enrollment.replied_since_baseline?
          return on_contact_reply(enrollment)
        end

        mark_step_completed(enrollment, node['id'])
        enrollment.clear_reply_watch!
        enrollment.update!(status: 'active')

        next_id = workflow.next_node_id(node['id'], source_handle: 'timeout')
        if next_id.blank?
          complete_enrollment(enrollment)
        else
          enrollment.update!(current_node_id: next_id)
          advance_from(workflow, enrollment, conversation, next_id, depth: 0)
        end
      end
    end
  end
end
