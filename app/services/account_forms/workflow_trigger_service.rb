# frozen_string_literal: true

# Handles workflow enrollment when a form is submitted.
# Isolated from OrchestratorService to avoid touching read-only legacy code (Strangler Fig).
module AccountForms
  class WorkflowTriggerService
    def self.call(account_id:, contact_id:, account_form_id:, submission_id:)
      new(
        account_id: account_id,
        contact_id: contact_id,
        account_form_id: account_form_id,
        submission_id: submission_id
      ).call
    end

    def initialize(account_id:, contact_id:, account_form_id:, submission_id:)
      @account_id = account_id
      @contact_id = contact_id
      @account_form_id = account_form_id
      @submission_id = submission_id
    end

    def call
      account = Account.find_by(id: @account_id)
      return unless account&.feature_enabled?('workflows')

      contact = account.contacts.find_by(id: @contact_id)
      return if contact.blank?

      account_form = account.account_forms.find_by(id: @account_form_id)
      return if account_form.blank?

      workflows = account.workflows
                         .for_trigger_event('form_submitted')
                         .where(active: true)
                         .limit(Workflows::Constants::MAX_WORKFLOWS_PER_EVENT)
      return if workflows.empty?

      changed_attributes = { 'account_form_id' => [nil, @account_form_id.to_s] }
      enrolled_conversation_id = nil

      workflows.each do |workflow|
        next if workflow.settings['allow_manual_start_only']

        conditions_match = conditions_match?(workflow, account_form)
        next unless conditions_match

        conversation = resolve_or_create_conversation(workflow, contact, account)
        next if conversation.blank?

        enrolled_conversation_id ||= conversation.id
        enroll_if_eligible(workflow, conversation, changed_attributes)
      end

      update_submission_conversation(enrolled_conversation_id)
    end

    private

    def conditions_match?(workflow, account_form)
      trigger = workflow.trigger_node
      return true if trigger.blank?

      conditions = trigger.dig('data', 'conditions') || []
      form_condition = conditions.find { |c| c['attribute_key'].to_s == 'account_form_id' }
      return false if form_condition.blank?

      form_values = Array(form_condition['values']).map(&:to_s)
      return false if form_values.empty?

      conditions.all? do |condition|
        evaluate_form_condition(condition, account_form)
      end
    end

    def evaluate_form_condition(condition, account_form)
      attribute = condition['attribute_key'].to_s
      operator = condition['filter_operator'].to_s
      values = Array(condition['values'])

      case attribute
      when 'account_form_id'
        string_match?(account_form.id.to_s, operator, values.map(&:to_s))
      when 'form_slug'
        string_match?(account_form.slug, operator, values.map(&:to_s))
      else
        true
      end
    end

    def string_match?(value, operator, values)
      case operator
      when 'equal_to'
        values.include?(value)
      when 'not_equal_to'
        values.exclude?(value)
      else
        true
      end
    end

    def resolve_or_create_conversation(workflow, contact, account)
      open_conversation = contact.conversations.open.order(updated_at: :desc).first
      return open_conversation if open_conversation.present?

      inbox_id = trigger_inbox_id(workflow)
      return nil if inbox_id.blank?

      inbox = account.inboxes.find_by(id: inbox_id)
      return nil if inbox.blank?

      create_conversation_for_contact(contact, inbox, account)
    end

    def trigger_inbox_id(workflow)
      trigger = workflow.trigger_node
      trigger&.dig('data', 'inbox_id')
    end

    def create_conversation_for_contact(contact, inbox, account)
      contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
      return nil if contact_inbox.blank?

      Conversation.create!(
        account: account,
        inbox: inbox,
        contact: contact,
        contact_inbox: contact_inbox,
        status: 'open',
        additional_attributes: { 'created_by_form' => true }
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[AccountForms::WorkflowTriggerService] Could not create conversation: #{e.message}"
      nil
    end

    def enroll_if_eligible(workflow, conversation, changed_attributes)
      return if enrollment_exists?(workflow, conversation)

      enrollment = WorkflowEnrollment.create!(
        workflow: workflow,
        conversation: conversation,
        contact_id: conversation.contact_id,
        account: workflow.account,
        enrollment_scope: workflow.settings['enrollment_scope'] || 'contact',
        status: 'active',
        current_node_id: workflow.trigger_node['id'],
        started_at: Time.current
      )
      Workflows::OrchestratorService.advance_from_node(
        workflow, enrollment, conversation, workflow.trigger_node['id']
      )
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.debug { "[AccountForms] enrollment race skipped workflow=#{workflow.id}" }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[AccountForms::WorkflowTriggerService] Enrollment failed: #{e.message}"
    end

    def enrollment_exists?(workflow, conversation)
      if workflow.settings['enrollment_scope'] == 'conversation'
        WorkflowEnrollment.in_progress.exists?(workflow_id: workflow.id, conversation_id: conversation.id)
      else
        WorkflowEnrollment.in_progress.exists?(workflow_id: workflow.id, contact_id: conversation.contact_id)
      end
    end

    def update_submission_conversation(conversation_id)
      return if conversation_id.blank?

      FormSubmission.where(id: @submission_id).update_all(conversation_id: conversation_id) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
