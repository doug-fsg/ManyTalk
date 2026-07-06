# frozen_string_literal: true

module AccountForms
  class LinkedWorkflowsResolver
    LINKAGE_AUTOMATES = 'automates'
    LINKAGE_PAUSED_FLOW = 'paused_flow'
    LINKAGE_CONTACT_ONLY = 'contact_only'

    pattr_initialize [:account!, form_ids: []]

    def self.build(account:, form_ids:)
      new(account: account, form_ids: form_ids).build
    end

    def self.linkage_state(linked_workflows)
      workflows = Array(linked_workflows)
      return LINKAGE_CONTACT_ONLY if workflows.empty?
      return LINKAGE_AUTOMATES if workflows.any? { |workflow| effectively_automates?(workflow) }

      LINKAGE_PAUSED_FLOW
    end

    def self.effectively_automates?(workflow)
      data = normalize_workflow_hash(workflow)
      data['active'] == true && data['manual_only'] != true
    end

    def self.normalize_workflow_hash(workflow)
      return {} unless workflow.is_a?(Hash)

      workflow.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end

    def build
      ids = Array(form_ids).map(&:to_i).uniq
      result = ids.index_with { [] }

      form_submitted_workflows.each do |workflow|
        form_ids_for_workflow(workflow).each do |form_id|
          next unless result.key?(form_id.to_i)

          result[form_id.to_i] << workflow_payload(workflow)
        end
      end

      result
    end

    private

    def form_submitted_workflows
      account.workflows.where(trigger_event_name: 'form_submitted')
    end

    def form_ids_for_workflow(workflow)
      conditions = workflow.trigger_node&.dig('data', 'conditions') || []
      Workflows::FormSubmittedLinkageParser.extract_form_ids(conditions).map(&:to_i)
    end

    def workflow_payload(workflow)
      {
        id: workflow.id,
        name: workflow.name,
        active: workflow.active?,
        manual_only: workflow.settings['allow_manual_start_only'] == true
      }
    end
  end
end
