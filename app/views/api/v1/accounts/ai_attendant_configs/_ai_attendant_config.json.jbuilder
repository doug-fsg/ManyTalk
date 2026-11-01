json.id resource.id
json.account_id resource.account_id
json.inbox_ids resource.inbox_ids
json.inbox_id resource.primary_inbox_id
json.active resource.active
json.pause_reason resource.pause_reason
json.digital_agent_name resource.digital_agent_name
json.avatar_id resource.avatar_id
json.avatar_url resource.avatar_url
json.agent_role resource.agent_role
json.agent_duties resource.agent_duties
json.agent_objective resource.agent_objective
json.behavior_steps resource.behavior_steps
json.behavior_step_mode resource.behavior_step_mode
json.company_context resource.company_context
json.topics_to_avoid resource.topics_to_avoid
json.handoff_conditions resource.handoff_conditions
json.handoff_customer_message resource.handoff_customer_message
json.schedule_mode resource.schedule_mode
json.detect_language resource.detect_language
json.debounce_seconds resource.debounce_seconds
json.many_ia_config_id resource.many_ia_config_id
reference_files = resource.reference_files.attached? ? resource.reference_files.to_a : []
json.reference_files(AiAttendant::ReferenceVariables.entries(reference_files)) do |entry|
  file = entry[:file]
  json.id file.id
  json.blob_id file.blob_id
  json.filename entry[:filename]
  json.token entry[:token]
  json.content_type file.content_type
  json.byte_size file.byte_size
  json.url ActiveStorageUrlHelper.url_for_attachment(file, only_path: true)
end
json.created_at resource.created_at
json.updated_at resource.updated_at
