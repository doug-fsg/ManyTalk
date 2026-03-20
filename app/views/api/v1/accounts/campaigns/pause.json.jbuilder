json.message 'Campaign paused'
json.campaign do
  json.partial! 'api/v1/models/campaign', formats: [:json], resource: @campaign
end
