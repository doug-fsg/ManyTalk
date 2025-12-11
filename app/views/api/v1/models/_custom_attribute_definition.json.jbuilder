json.id resource.id
json.attribute_display_name resource.attribute_display_name
json.attribute_display_type resource.attribute_display_type
json.attribute_description resource.attribute_description
json.attribute_key resource.attribute_key
json.regex_pattern resource.regex_pattern
json.regex_cue resource.regex_cue

# Normalizar attribute_values para sempre retornar um array
# Se for hash (formato novo com stages e permissions), extrair apenas o array de stages
# Se for array (formato legado), usar diretamente
# Se for nil ou outro tipo, retornar array vazio
if resource.attribute_values.is_a?(Hash)
  # Tentar obter stages com chave string ou símbolo
  stages = resource.attribute_values['stages'] || resource.attribute_values[:stages] || resource.attribute_values['values'] || resource.attribute_values[:values]
  if stages.is_a?(Array)
    # Se os stages são objetos com name e color, retornar como estão
    # Se são strings, retornar como array de strings (formato legado)
    json.attribute_values stages
  elsif stages.is_a?(Hash)
    # Formato novo: { "nome": { color } } -> converter para array de objetos
    json.attribute_values stages.map { |name, data| { name: name.to_s, color: data['color'] || data[:color] } }
  else
    json.attribute_values []
  end
elsif resource.attribute_values.is_a?(Array)
  # Formato legado: array de strings ou array de objetos
  json.attribute_values resource.attribute_values
else
  json.attribute_values []
end

json.attribute_model resource.attribute_model
json.default_value resource.default_value
json.is_kanban resource.is_kanban
json.created_at resource.created_at
json.updated_at resource.updated_at

# Incluir permissões para pipelines Kanban
if resource.is_kanban && resource.attribute_values.is_a?(Hash)
  json.permissions resource.attribute_values['permissions'] || {}
end
