json.id enrollment.id
json.workflow_id enrollment.workflow_id
json.workflow_name enrollment.workflow.name
json.conversation_id enrollment.conversation_id
json.status enrollment.status
json.current_node_id enrollment.current_node_id

current_node = enrollment.workflow.find_node(enrollment.current_node_id)
json.current_node_label current_node&.dig('data', 'label') || current_node&.dig('type')

next_execution = enrollment.workflow_step_executions.find_by(status: 'scheduled')
json.next_scheduled_at next_execution&.scheduled_at

reply_watch = (enrollment.context || {})['reply_watch']
if reply_watch.present?
  json.reply_watch do
    json.node_id reply_watch['node_id']
    json.deadline_at reply_watch['deadline_at']
    json.baseline_at reply_watch['baseline_at']
  end
else
  json.reply_watch nil
end

json.started_at enrollment.started_at
json.paused_at enrollment.paused_at
json.pause_reason enrollment.pause_reason
json.completed_at enrollment.completed_at
json.cancelled_at enrollment.cancelled_at

if enrollment.started_by
  json.started_by do
    json.id enrollment.started_by.id
    json.name enrollment.started_by.name
  end
else
  json.started_by nil
end

if enrollment.paused_by
  json.paused_by do
    json.id enrollment.paused_by.id
    json.name enrollment.paused_by.name
  end
else
  json.paused_by nil
end

timeline_meta = Workflows::TimelineBuilder.new(enrollment).build
json.step_index timeline_meta[:step_index]
json.total_steps timeline_meta[:total_steps]
json.timeline timeline_meta[:timeline]

nodes = enrollment.workflow.graph['nodes'] || []
json.available_stages nodes.select { |n| n.dig('data', 'label').present? }.map { |n|
  { id: n['id'], label: n.dig('data', 'label'), type: n['type'] }
}
