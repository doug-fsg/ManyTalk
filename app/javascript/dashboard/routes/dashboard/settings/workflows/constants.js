import {
  AUTOMATION_RULE_EVENTS,
  AUTOMATION_ACTION_TYPES,
  AUTOMATIONS,
} from '../automation/constants';
import {
  OPERATOR_TYPES_1,
  OPERATOR_TYPES_2,
  OPERATOR_TYPES_3,
  OPERATOR_TYPES_4,
} from '../automation/operators';

/** Event key for mid-flow condition nodes (merged v1 attributes + extras). */
export const WORKFLOW_FLOW_EVENT_KEY = 'workflow_flow';

const WORKFLOW_EXTRA_CONDITIONS = [
  {
    key: 'labels',
    name: 'Etiquetas',
    attributeI18nKey: 'LABELS',
    inputType: 'multi_select',
    filterOperators: OPERATOR_TYPES_1,
  },
  {
    key: 'assignee_id',
    name: 'Atendente',
    attributeI18nKey: 'ASSIGNEE_NAME',
    inputType: 'search_select',
    filterOperators: OPERATOR_TYPES_3,
  },
  {
    key: 'team_id',
    name: 'Equipe',
    attributeI18nKey: 'TEAM_NAME',
    inputType: 'search_select',
    filterOperators: OPERATOR_TYPES_3,
  },
  {
    key: 'created_at',
    name: 'Criada em',
    attributeI18nKey: 'CREATED_AT',
    inputType: 'date',
    filterOperators: OPERATOR_TYPES_4,
  },
  {
    key: 'last_activity_at',
    name: 'Última atividade',
    attributeI18nKey: 'LAST_ACTIVITY',
    inputType: 'date',
    filterOperators: OPERATOR_TYPES_4,
  },
];

/** Automation types catalog: v1 events + merged list for flow condition nodes. */
export const buildWorkflowAutomationTypes = () => {
  const types = JSON.parse(JSON.stringify(AUTOMATIONS));
  const seen = new Set();
  const merged = [];

  ['conversation_created', 'conversation_updated'].forEach(eventKey => {
    (types[eventKey].conditions || []).forEach(condition => {
      if (condition.disabled || seen.has(condition.key)) return;
      seen.add(condition.key);
      merged.push(condition);
    });
  });

  WORKFLOW_EXTRA_CONDITIONS.forEach(condition => {
    if (seen.has(condition.key)) return;
    seen.add(condition.key);
    merged.push(condition);
  });

  types[WORKFLOW_FLOW_EVENT_KEY] = { conditions: merged, actions: [] };
  return types;
};

export const WORKFLOW_TRIGGER_EVENTS = AUTOMATION_RULE_EVENTS;

export const WORKFLOW_ACTION_TYPES = [
  ...AUTOMATION_ACTION_TYPES,
  {
    key: 'add_private_note',
    label: 'Adicionar nota privada',
    inputType: 'textarea',
  },
];

export const WORKFLOW_NODE_PALETTE = [
  {
    group: 'Gatilho',
    type: 'trigger',
    label: 'Gatilho',
  },
  {
    group: 'Tempo',
    type: 'wait',
    label: 'Espera',
  },
  {
    group: 'Lógica',
    type: 'condition',
    label: 'Condição',
  },
  {
    group: 'Ação',
    type: 'action',
    label: 'Ação',
  },
];

export const DEFAULT_WORKFLOW_GRAPH = {
  nodes: [
    {
      id: 'trigger_1',
      type: 'trigger',
      x: 120,
      y: 120,
      data: {
        event_name: 'conversation_created',
        conditions: [],
      },
    },
  ],
  edges: [],
  settings: {
    cancel_on_contact_reply: true,
    cancel_on_conversation_resolved: true,
  },
};

export const logicFlowNodeType = () => 'workflow-card';
