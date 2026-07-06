json.id account_form.id
json.account_id account_form.account_id
json.name account_form.name
json.slug account_form.slug
json.status account_form.status
json.definition AccountForms::DefinitionEnricher.call(account_form)
json.branding account_form.branding_for_api
json.settings account_form.settings
json.public_url account_form.public_url
json.submissions_count account_form.submissions_count
json.created_on account_form.created_at.to_i
json.updated_on account_form.updated_at.to_i
linked = local_assigns[:linked_workflows_by_form_id]&.[](account_form.id) || []
json.linked_workflows linked
json.linkage_state AccountForms::LinkedWorkflowsResolver.linkage_state(linked)
