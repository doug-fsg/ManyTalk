json.payload do
  json.array! @templates do |template|
    json.key template[:key]
    json.name template[:name]
    json.description template[:description]
    json.category template[:category]
    json.trigger_event template[:trigger_event]
    json.step_count template[:step_count]
  end
end
