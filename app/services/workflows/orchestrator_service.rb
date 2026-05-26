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
          process_workflow_trigger(workflow, conversation, message, changed_attributes)
        end
      end

      def on_step(enrollment_id:, node_id:)
        enrollment = WorkflowEnrollment.find_by(id: enrollment_id)
        return if enrollment.blank? || enrollment.cancelled? || enrollment.completed?
        return unless enrollment.may_run_step?(node_id)

        workflow = enrollment.workflow
        conversation = enrollment.conversation
        node = workflow.find_node(node_id)
        return if node.blank?

        enrollment.with_lock do
          return if enrollment.reload.cancelled?

          if node['type'] == 'wait' && enrollment.waiting?
            resume_after_wait(workflow, enrollment, conversation, node)
          else
            process_node(workflow, enrollment, conversation, node)
          end
        end
      end

      private

      def process_workflow_trigger(workflow, conversation, message, changed_attributes)
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
            account: workflow.account,
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
        WorkflowEnrollment.active_or_waiting.exists?(workflow_id: workflow.id, conversation_id: conversation.id)
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
        when 'wait'
          schedule_wait(workflow, enrollment, node)
        when 'condition'
          handle_condition(workflow, enrollment, conversation, node, depth: depth)
        else
          complete_enrollment(enrollment)
        end
      end

      def execute_action(workflow, enrollment, conversation, node)
        data = node['data'] || {}
        Workflows::ActionService.new(
          workflow,
          workflow.account,
          conversation,
          node_id: node['id']
        ).perform_action(data['action_name'], data['action_params'] || [])
      end

      def schedule_wait(workflow, enrollment, node)
        data = node['data'] || {}
        # Zero/nil duration schedules an immediate job; Sidekiq can run it before we set status to
        # `waiting`, so `on_step` hits `process_node` again instead of `resume_after_wait`. Enforce a
        # minimum delay and persist `waiting` before enqueueing.
        wait_delay = [wait_duration(data), 1.second].max

        execution = enrollment.workflow_step_executions.find_or_initialize_by(node_id: node['id'])
        return if execution.status == 'completed'

        enrollment.reload
        if execution.persisted? && execution.status == 'scheduled' && enrollment.waiting? && enrollment.current_node_id == node['id']
          return
        end

        ActiveRecord::Base.transaction do
          enrollment.update!(status: 'waiting', current_node_id: node['id'])
          execution.update!(
            status: 'scheduled',
            scheduled_at: Time.current + wait_delay,
            job_id: nil
          )
        end

        job = Workflows::StepJob.set(wait: wait_delay).perform_later(enrollment.id, node['id'])
        execution.update!(job_id: job&.provider_job_id)
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
          conditions: data['conditions'] || []
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
        when 'wait'
          schedule_wait(workflow, enrollment, node)
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
    end
  end
end
