export function buildContactsByFormRoute(accountId, formId) {
  return {
    name: 'contacts_forms_dashboard',
    params: {
      accountId: String(accountId),
      formId: String(formId),
    },
  };
}
