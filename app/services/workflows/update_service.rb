# frozen_string_literal: true

module Workflows
  class UpdateService
    pattr_initialize [:workflow!, :user!, :params!]

    def perform
      if workflow.active? && graph_changed?
        return failure(['Desative o fluxo para editar o diagrama'])
      end

      attrs = {
        name: params[:name],
        description: params[:description],
        updated_by: user
      }
      attrs[:active] = params[:active] if params.key?(:active)

      if graph_changed? && !workflow.active?
        graph = normalize_graph(params[:graph])
        validation = GraphValidationService.new(graph: graph, account: workflow.account).perform
        return failure(validation[:errors]) unless validation[:valid]

        attrs[:graph] = graph
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
