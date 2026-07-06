import {
  extractFormIdsFromConditions,
  FORM_SUBMITTED_EVENT_KEY,
} from '../workflows/workflowExtensions';

export const LINKAGE_STATES = {
  AUTOMATES: 'automates',
  PAUSED_FLOW: 'paused_flow',
  CONTACT_ONLY: 'contact_only',
};

const EMPTY_LINKAGE = {
  state: LINKAGE_STATES.CONTACT_ONLY,
  workflows: [],
};

const getTriggerConditions = workflow => {
  const graph = workflow.graph || {};
  const nodes = graph.nodes || [];
  const trigger = nodes.find(node => node.type === 'trigger');
  if (!trigger) return [];

  const data = trigger.data || trigger.properties || {};
  return data.conditions || [];
};

export const effectivelyAutomates = workflow =>
  Boolean(workflow?.active) && !workflow?.manual_only;

export const classifyLinkage = workflows => {
  const list = workflows || [];
  if (!list.length) return { ...EMPTY_LINKAGE };

  const hasEffective = list.some(effectivelyAutomates);
  return {
    state: hasEffective ? LINKAGE_STATES.AUTOMATES : LINKAGE_STATES.PAUSED_FLOW,
    workflows: list,
  };
};

export const buildFormWorkflowMap = workflows => {
  const map = new Map();

  (workflows || []).forEach(workflow => {
    if (workflow.trigger_event_name !== FORM_SUBMITTED_EVENT_KEY) return;

    const formIds = extractFormIdsFromConditions(getTriggerConditions(workflow));
    formIds.forEach(formId => {
      const key = String(formId);
      const linked = map.get(key) || [];
      linked.push({
        id: workflow.id,
        name: workflow.name,
        active: Boolean(workflow.active),
        manual_only: Boolean(workflow.graph?.settings?.allow_manual_start_only),
      });
      map.set(key, linked);
    });
  });

  return map;
};

export const resolveFormLinkage = (map, formId) => {
  const workflows = map.get(String(formId)) || [];
  return classifyLinkage(workflows);
};

export const linkageFromForm = (form, fallbackMap = null) => {
  if (form?.linkage_state) {
    return {
      state: form.linkage_state,
      workflows: form.linked_workflows || [],
    };
  }

  if (fallbackMap) {
    return resolveFormLinkage(fallbackMap, form.id);
  }

  return { ...EMPTY_LINKAGE };
};
