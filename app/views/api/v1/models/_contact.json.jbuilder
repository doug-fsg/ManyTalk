json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.identifier resource.identifier
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
# Incluir pipeline positions para ordenação no Kanban
if resource.respond_to?(:contact_pipeline_positions)
  json.pipeline_positions do
    json.array! resource.contact_pipeline_positions do |position|
      json.pipeline_id position.pipeline_id
      json.stage_id position.stage_id
      json.position position.position
      json.entered_at position.entered_at&.iso8601
      json.created_at position.created_at&.iso8601
      json.deal_value position.deal_value
      json.metadata position.metadata || {}
      if position.assignee.present?
        json.assignee do
          json.id position.assignee.id
          json.name position.assignee.name
          json.available_name position.assignee.available_name
          json.avatar_url position.assignee.avatar_url
          json.thumbnail position.assignee.avatar_url
        end
      else
        json.assignee nil
      end
    end
  end
end
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! resource.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end
