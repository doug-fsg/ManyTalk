json.name @account_form.name
json.branding @account_form.branding_for_api
json.definition AccountForms::DefinitionEnricher.call(@account_form)
