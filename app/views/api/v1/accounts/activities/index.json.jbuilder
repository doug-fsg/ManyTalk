json.array! @activities do |activity|
  json.partial! 'api/v1/models/activity', activity: activity
end

