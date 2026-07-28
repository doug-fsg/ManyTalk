json.payload do
  json.array! @labels do |label|
    json.id label.id
    json.title label.title
    json.description label.description
    json.color label.color
    json.show_on_sidebar label.show_on_sidebar
    json.label_group_id label.label_group_id
    json.label_group_name label.label_group&.name
  end
end
