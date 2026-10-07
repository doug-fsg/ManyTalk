json.payload do
  json.partial! 'api/v1/accounts/workflow_schedules/partials/workflow_schedule',
                schedule: @workflow_schedule
end
