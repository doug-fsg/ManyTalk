json.payload do
  json.array! @account_forms do |account_form|
    json.partial! 'api/v1/accounts/account_forms/partials/account_form',
                  account_form: account_form,
                  linked_workflows_by_form_id: @linked_workflows_by_form_id
  end
end
