export const AVAILABLE_CUSTOM_ROLE_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
  'contact_manage',
  'report_manage',
  'knowledge_base_manage',
  'workflow_manage',
  'automation_manage',
  'form_manage',
  'crm_manage',
  'campaign_manage',
  'billing_manage',
];

export const BILLING_ROUTE_PERMISSIONS = ['administrator', 'billing_manage'];

export const CONVERSATION_ACCESS_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
];

export const CONVERSATION_ROUTE_PERMISSIONS = [
  'administrator',
  'agent',
  ...CONVERSATION_ACCESS_PERMISSIONS,
];

export const CAMPAIGN_ROUTE_PERMISSIONS = [
  'administrator',
  'agent',
  'campaign_manage',
];

export const AUTOMATION_ROUTE_PERMISSIONS = [
  'administrator',
  'agent',
  'automation_manage',
];

export const WORKFLOW_ROUTE_PERMISSIONS = [
  'administrator',
  'agent',
  'workflow_manage',
];

export const FORM_ROUTE_PERMISSIONS = [
  'administrator',
  'agent',
  'form_manage',
  'workflow_manage',
];
