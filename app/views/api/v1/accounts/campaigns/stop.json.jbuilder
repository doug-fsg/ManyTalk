json.message 'Campaign stopped'
json.campaign do
  json.partial! 'api/v1/models/campaign', formats: [:json], resource: @campaign
end
