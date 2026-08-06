module Workflows
  # Normalizes action-node payload to a list of actions.
  # Supports legacy single action_name/action_params and the actions[] array.
  module ActionNodeData
    module_function

    def items(data)
      payload = (data || {}).with_indifferent_access
      actions = Array(payload[:actions]).compact
      if actions.present?
        return actions.filter_map do |item|
          next unless item.is_a?(Hash)

          entry = item.with_indifferent_access
          next if entry[:action_name].blank?

          {
            'action_name' => entry[:action_name].to_s,
            'action_params' => Array(entry[:action_params])
          }
        end
      end

      return [] if payload[:action_name].blank?

      [{
        'action_name' => payload[:action_name].to_s,
        'action_params' => Array(payload[:action_params])
      }]
    end
  end
end
