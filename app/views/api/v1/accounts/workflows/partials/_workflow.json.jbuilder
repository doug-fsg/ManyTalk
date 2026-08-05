json.id workflow.id
json.account_id workflow.account_id
json.name workflow.name
json.description workflow.description
json.active workflow.active?
json.trigger_event_name workflow.trigger_event_name
json.graph workflow.graph
json.created_on workflow.created_at.to_i
json.updated_on workflow.updated_at.to_i
json.created_by_id workflow.created_by_id
json.updated_by_id workflow.updated_by_id
if local_assigns[:metrics]
  json.metrics do
    json.active_count metrics[:active_count] || 0
    json.reply_rate_30d metrics[:reply_rate_30d]
    json.completion_rate_30d metrics[:completion_rate_30d]
  end
end
json.conflicting_automations workflow.conflicting_automation_names
