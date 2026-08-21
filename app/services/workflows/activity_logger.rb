# frozen_string_literal: true

module Workflows
  class ActivityLogger
    WAIT_KIND_KEYS = {
      'wait' => 'wait',
      'wait_for_reply' => 'wait_for_reply',
      'ai_wait_for_intent' => 'wait_for_intent'
    }.freeze

    class << self
      def actor_name(executed_by)
        case executed_by
        when Workflow
          executed_by.name
        when AutomationRule
          'Automation System'
        end
      end

      def log(conversation, key, **vars)
        return if conversation.blank?

        content = I18n.t("conversations.activity.workflow.#{key}", **vars)
        return if content.blank?

        ::Conversations::ActivityMessageJob.perform_later(
          conversation,
          {
            account_id: conversation.account_id,
            inbox_id: conversation.inbox_id,
            message_type: :activity,
            content: content
          }
        )
      end

      def log_started(conversation, workflow, user: nil)
        if user.present?
          log(conversation, 'started_by_user', user_name: user.name, workflow_name: workflow.name)
        else
          log(conversation, 'started_automatically', workflow_name: workflow.name)
        end
      end

      def log_cancelled(conversation, workflow, user: nil, reason: nil)
        if user.present?
          log(conversation, 'cancelled_by_user', user_name: user.name, workflow_name: workflow.name)
        else
          log(
            conversation,
            'cancelled_automatically',
            workflow_name: workflow.name,
            reason: reason_label(reason)
          )
        end
      end

      def log_paused(conversation, workflow, user: nil, reason: nil)
        if user.present?
          log(conversation, 'paused_by_user', user_name: user.name, workflow_name: workflow.name)
        else
          log(
            conversation,
            'paused_automatically',
            workflow_name: workflow.name,
            reason: reason_label(reason)
          )
        end
      end

      def log_resumed(conversation, workflow, user:)
        return if user.blank?

        log(conversation, 'resumed_by_user', user_name: user.name, workflow_name: workflow.name)
      end

      def log_completed(conversation, workflow)
        log(conversation, 'completed', workflow_name: workflow.name)
      end

      def log_failed(conversation, workflow)
        log(conversation, 'failed', workflow_name: workflow.name)
      end

      def log_waiting(conversation, workflow, node_type:)
        kind = I18n.t(
          "conversations.activity.workflow.wait_kinds.#{WAIT_KIND_KEYS[node_type] || 'wait'}"
        )
        log(conversation, 'waiting', workflow_name: workflow.name, kind: kind)
      end

      def log_resumed_after_timeout(conversation, workflow)
        log(conversation, 'resumed_after_timeout', workflow_name: workflow.name)
      end

      def reason_label(reason)
        key = reason.to_s.presence || 'unknown'
        I18n.t(
          "conversations.activity.workflow.reasons.#{key}",
          default: I18n.t('conversations.activity.workflow.reasons.unknown')
        )
      end
    end
  end
end
