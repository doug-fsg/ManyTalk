import { WORKFLOW_ACTION_TYPES } from './constants';

const cloneParams = params => {
  if (!Array.isArray(params)) return [];
  return params.map(item => item);
};

const normalizeActionItem = action => ({
  action_name: (action && action.action_name) || 'send_message',
  action_params: cloneParams(action && action.action_params),
});

const paramsHaveContent = params =>
  Array.isArray(params) &&
  params.some(value => value !== undefined && value !== null && String(value).length > 0);

/** Normalize action-node data to a list of { action_name, action_params }. */
export const normalizeActionsList = data => {
  const raw = data || {};
  let list = [];

  if (Array.isArray(raw.actions) && raw.actions.length) {
    list = raw.actions.map(normalizeActionItem);
  } else if (raw.action_name) {
    list = [
      normalizeActionItem({
        action_name: raw.action_name,
        action_params: raw.action_params,
      }),
    ];
  } else {
    list = [defaultWorkflowAction()];
  }

  // Heal stale nested actions[] when legacy top-level params are richer
  // (e.g. message saved only on action_params).
  if (
    list.length &&
    !paramsHaveContent(list[0].action_params) &&
    paramsHaveContent(raw.action_params)
  ) {
    list = list.map((item, index) =>
      index === 0
        ? { ...item, action_params: cloneParams(raw.action_params) }
        : item
    );
  }

  return list;
};

export const defaultWorkflowAction = () => ({
  action_name: 'send_message',
  action_params: [''],
});

/** Persist actions[] and mirror the first item on legacy fields for canvas/compat. */
export const syncActionNodeFields = actions => {
  const list =
    Array.isArray(actions) && actions.length
      ? actions.map(normalizeActionItem)
      : [defaultWorkflowAction()];
  const first = list[0];
  return {
    actions: list,
    action_name: first.action_name,
    action_params: cloneParams(first.action_params),
  };
};

export const workflowActionLabel = actionName => {
  const found = WORKFLOW_ACTION_TYPES.find(item => item.key === actionName);
  return (found && found.label) || actionName || '—';
};

export const actionListSubtitle = data => {
  const list = normalizeActionsList(data);
  if (!list.length) return '—';
  const first = workflowActionLabel(list[0].action_name);
  if (list.length === 1) return first;
  return `${first} +${list.length - 1}`;
};
