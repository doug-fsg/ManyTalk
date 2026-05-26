json.payload do
  json.array! @workflows do |workflow|
    json.partial! 'api/v1/accounts/workflows/partials/workflow', workflow: workflow
  end
end
