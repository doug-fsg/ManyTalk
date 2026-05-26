# frozen_string_literal: true

module Workflows
  class CreateService
    pattr_initialize [:account!, :user!, :params!]

    def perform
      graph = normalize_graph(params[:graph])
      validation = GraphValidationService.new(graph: graph, account: account).perform
      return failure(validation[:errors]) unless validation[:valid]

      workflow = nil
      ActiveRecord::Base.transaction do
        workflow = account.workflows.create!(
          name: params[:name],
          description: params[:description],
          active: params.fetch(:active, false),
          graph: graph,
          created_by: user,
          updated_by: user
        )
      end

      { workflow: workflow, errors: [] }
    end

    private

    def normalize_graph(raw_graph)
      graph = Workflows::GraphParamsParser.to_hash(raw_graph)
      graph['settings'] = Constants::DEFAULT_SETTINGS.merge(graph['settings'] || {})
      graph
    end

    def failure(errors)
      { workflow: nil, errors: errors }
    end
  end
end
