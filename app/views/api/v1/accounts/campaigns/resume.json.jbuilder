json.message 'Campaign resuming'
json.campaign do
  json.partial! 'api/v1/models/campaign', formats: [:json], resource: @campaign
end
