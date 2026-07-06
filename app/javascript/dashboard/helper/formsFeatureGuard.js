import { isWorkflowsFeatureEnabled } from './workflowsFeatureGuard';

export const requireFormsAccess = (to, from, next) => {
  const accountId = to.params.accountId;

  if (!isWorkflowsFeatureEnabled(accountId)) {
    next({ name: 'automation_list', params: { accountId } });
    return;
  }

  next();
};
