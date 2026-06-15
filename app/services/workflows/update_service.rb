# frozen_string_literal: true

module Workflows
  class UpdateService
    pattr_initialize [:workflow!, :user!, :params!]

    def perform
      deactivating = params.key?(:active) && !ActiveModel::Type::Boolean.new.cast(params[:active])
      activating   = params.key?(:active) && ActiveModel::Type::Boolean.new.cast(params[:active]) && !workflow.active?

      if workflow.active? && graph_changed? && !deactivating
        return failure([I18n.t('workflows.errors.deactivate_to_edit')])
      end

      attrs = {
        name: params[:name],
        description: params[:description],
        updated_by: user
      }
      attrs[:active] = params[:active] if params.key?(:active)

      if graph_changed? && (!workflow.active? || deactivating)
        graph = normalize_graph(params[:graph])
        validation = GraphValidationService.new(graph: graph, account: workflow.account).perform
        return failure(GraphValidationService.error_messages(validation[:errors])) unless validation[:valid]

        attrs[:graph] = graph
      elsif activating
        graph_to_validate = workflow.graph
        validation = GraphValidationService.new(graph: graph_to_validate, account: workflow.account).perform
        return failure(GraphValidationService.error_messages(validation[:errors])) unless validation[:valid]
      end

      ActiveRecord::Base.transaction do
        workflow.update!(attrs.compact)
      end

      { workflow: workflow.reload, errors: [] }
    end

    private

    def graph_changed?
      params.key?(:graph) && params[:graph].present?
    end

    def normalize_graph(raw_graph)
      graph = Workflows::GraphParamsParser.to_hash(raw_graph)
      graph = workflow.graph if graph.blank?
      graph['settings'] = Constants::DEFAULT_SETTINGS.merge(graph['settings'] || workflow.settings)
      graph
    end

    def failure(errors)
      { workflow: workflow, errors: errors }
    end
  end
end
