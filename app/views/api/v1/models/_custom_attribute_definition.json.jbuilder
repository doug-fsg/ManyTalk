json.id resource.id
json.attribute_display_name resource.attribute_display_name
json.attribute_display_type resource.attribute_display_type
json.attribute_description resource.attribute_description
json.attribute_key resource.attribute_key
json.regex_pattern resource.regex_pattern
json.regex_cue resource.regex_cue
json.attribute_values CustomAttributes::ValuesNormalizer.for_api(resource.attribute_values)
json.attribute_model resource.attribute_model
json.default_value resource.default_value
json.is_kanban resource.is_kanban
json.created_at resource.created_at
json.updated_at resource.updated_at

# Incluir permissões para pipelines Kanban
if resource.is_kanban && resource.attribute_values.is_a?(Hash)
  json.permissions resource.attribute_values['permissions'] || {}
  # Incluir permissão do usuário atual
  if Current.user.present?
    json.user_permission resource.user_permission(Current.user).to_s
    json.can_view resource.can_view?(Current.user)
  else
    # Se não há usuário (API pública), não pode ver
    json.user_permission 'none'
    json.can_view false
  end
end
