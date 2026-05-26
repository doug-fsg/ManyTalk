json.payload do
  json.partial! 'api/v1/accounts/workflows/partials/workflow', workflow: @workflow
end
