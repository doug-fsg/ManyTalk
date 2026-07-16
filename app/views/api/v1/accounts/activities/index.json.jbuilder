json.meta do
  json.count @activities_count
  if @activities.respond_to?(:current_page)
    json.current_page @activities.current_page
    json.total_pages @activities.total_pages
  end
end

json.payload do
  json.array! @activities do |activity|
    json.partial! 'api/v1/models/activity', activity: activity
  end
end
