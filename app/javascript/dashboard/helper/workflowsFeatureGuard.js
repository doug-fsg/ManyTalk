import store from '../store';
import { FEATURE_FLAGS } from '../featureFlags';

export const isWorkflowsFeatureEnabled = accountId => {
  const id = Number(accountId);
  if (!id) return false;

  return store.getters['accounts/isFeatureEnabledonAccount'](
    id,
    FEATURE_FLAGS.WORKFLOWS
  );
};

export const requireWorkflowsFeature = (to, from, next) => {
  if (!isWorkflowsFeatureEnabled(to.params.accountId)) {
    next({
      name: 'automation_list',
      params: { accountId: to.params.accountId },
    });
    return;
  }
  next();
};
