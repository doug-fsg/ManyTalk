json.id activity.id
json.contact_id activity.contact_id
json.activity_type activity.activity_type
json.title activity.title
json.description activity.description
json.status activity.status
json.scheduled_at activity.scheduled_at
json.message_content activity.message_content if activity.scheduled_message?
json.metadata activity.metadata || {}
json.created_at activity.created_at
json.updated_at activity.updated_at

json.inbox do
  json.id activity.inbox.id
  json.name activity.inbox.name
  json.channel_type activity.inbox.channel_type
end if activity.inbox

json.user do
  json.partial! 'api/v1/models/user', formats: [:json], resource: activity.user
end if activity.user

json.assignee do
  json.partial! 'api/v1/models/user', formats: [:json], resource: activity.assignee
end if activity.assignee

json.contact do
  json.partial! 'api/v1/models/contact', formats: [:json], resource: activity.contact
end if activity.contact

json.conversation do
  json.id activity.conversation.id
  json.display_id activity.conversation.display_id
end if activity.conversation

if activity.contact_pipeline_position&.pipeline.present?
  json.pipeline do
    pipeline = activity.contact_pipeline_position.pipeline
    json.id pipeline.id
    json.name pipeline.attribute_display_name
    json.stage_id activity.contact_pipeline_position.stage_id
  end
end

