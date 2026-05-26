# frozen_string_literal: true

module Workflows
  # Rails passes nested JSON as ActionController::Parameters, not Hash.
  module GraphParamsParser
    module_function

    def to_hash(raw_graph)
      case raw_graph
      when ActionController::Parameters
        raw_graph.to_unsafe_h.deep_stringify_keys
      when Hash
        raw_graph.deep_stringify_keys
      else
        {}
      end
    end
  end
end
