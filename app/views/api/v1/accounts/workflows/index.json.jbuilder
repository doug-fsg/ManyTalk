json.payload do
  json.array! @workflows do |workflow|
    json.partial! 'api/v1/accounts/workflows/partials/workflow',
                  workflow: workflow,
                  metrics: @metrics[workflow.id] || { active_count: 0, reply_rate_30d: nil }
  end
end
