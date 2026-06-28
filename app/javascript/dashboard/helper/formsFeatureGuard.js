import store from '../store';
import { FEATURE_FLAGS } from '../featureFlags';

export const requireFormsAccess = (to, from, next) => {
  const accountId = to.params.accountId;
  const workflowsEnabled = store.getters['accounts/isFeatureEnabledonAccount'](
    Number(accountId),
    FEATURE_FLAGS.WORKFLOWS
  );

  if (!workflowsEnabled) {
    next({ name: 'automation_list', params: { accountId } });
    return;
  }

  if (store.getters.getCurrentRole !== 'administrator') {
    next({ name: 'workflows_list', params: { accountId } });
    return;
  }

  next();
};
