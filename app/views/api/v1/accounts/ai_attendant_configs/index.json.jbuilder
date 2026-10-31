json.array! @ai_attendant_configs do |ai_attendant_config|
  json.partial! 'api/v1/accounts/ai_attendant_configs/ai_attendant_config', resource: ai_attendant_config
end
