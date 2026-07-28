json.payload do
  json.array! @label_groups do |label_group|
    json.id label_group.id
    json.name label_group.name
    json.position label_group.position
  end
end
