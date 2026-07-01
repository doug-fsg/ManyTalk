json.name @account_form.name
json.branding @account_form.branding
json.definition AccountForms::DefinitionEnricher.call(@account_form)
