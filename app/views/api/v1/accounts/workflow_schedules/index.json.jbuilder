json.payload do
  json.array! @workflow_schedules do |schedule|
    json.partial! 'api/v1/accounts/workflow_schedules/partials/workflow_schedule',
                  schedule: schedule,
                  audience_count: @audience_counts[[schedule.pipeline_id, schedule.stage_id]].to_i
  end
end
