json.meta do
  json.count @campaigns_count
  json.current_page @campaigns.current_page
  json.total_pages @campaigns.total_pages
end

json.payload do
  json.array! @campaigns do |campaign|
    json.partial! 'api/v1/models/campaign', formats: [:json], resource: campaign
  end
end
