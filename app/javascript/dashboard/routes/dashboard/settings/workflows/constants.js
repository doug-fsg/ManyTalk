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
  {
    key: 'contact_replied_since_baseline',
    name: 'Cliente respondeu',
    attributeI18nKey: 'CONTACT_REPLIED',
    inputType: 'plain_text',
    filterOperators: [{ key: 'is_present', value: 'É verdadeiro' }],
  },
  {
    key: 'contact_not_replied_since_baseline',
    name: 'Cliente não respondeu',
    attributeI18nKey: 'CONTACT_NOT_REPLIED',
    inputType: 'plain_text',
    filterOperators: [{ key: 'is_present', value: 'É verdadeiro' }],
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

  types.manual = { conditions: [], actions: [] };

  types.contact_kanban_stage_changed = {
    conditions: [
      {
        key: 'kanban_pipeline_id',
        name: 'Pipeline CRM',
        attributeI18nKey: 'KANBAN_PIPELINE',
        inputType: 'search_select',
        filterOperators: OPERATOR_TYPES_3,
      },
      {
        key: 'kanban_stage_id',
        name: 'Estágio CRM',
        attributeI18nKey: 'KANBAN_STAGE',
        inputType: 'plain_text',
        filterOperators: OPERATOR_TYPES_1,
      },
    ],
    actions: [],
  };

  return types;
};

export const WORKFLOW_TRIGGER_EVENTS = [
  ...AUTOMATION_RULE_EVENTS,
  { key: 'manual', value: 'Início manual (pela conversa)' },
  { key: 'contact_kanban_stage_changed', value: 'Estágio do CRM alterado' },
];

export const WORKFLOW_ACTION_TYPES = [
  ...AUTOMATION_ACTION_TYPES,
  {
    key: 'add_private_note',
    label: 'Adicionar nota privada',
    inputType: 'textarea',
  },
  {
    key: 'send_whatsapp_external',
    label: 'Enviar para WhatsApp externo',
    inputType: 'whatsapp_external',
  },
];

export const WORKFLOW_WAIT_RESPONDERS = [
  { key: 'contact', labelKey: 'WORKFLOW.EDITOR.WAIT_RESPONDER_CONTACT' },
  { key: 'agent', labelKey: 'WORKFLOW.EDITOR.WAIT_RESPONDER_AGENT' },
  { key: 'any', labelKey: 'WORKFLOW.EDITOR.WAIT_RESPONDER_ANY' },
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
    group: 'Tempo',
    type: 'wait_for_reply',
    label: 'Aguardar resposta',
  },
  {
    group: 'Lógica',
    type: 'condition',
    label: 'Se (IF)',
  },
  {
    group: 'Ação',
    type: 'action',
    label: 'Ação',
  },
  {
    group: 'Inteligencia Artificial',
    type: 'ai_outreach',
    label: 'Chamar cliente',
  },
  {
    group: 'Inteligencia Artificial',
    type: 'ai_conversation_analysis',
    label: 'Avaliar Conversa',
  },
];

export const AI_OUTREACH_OBJECTIVES = [
  {
    key: 'reengagement',
    labelKey: 'WORKFLOW.EDITOR.AI_OBJECTIVE_REENGAGEMENT',
    prompt: 'Retome o contato com o cliente de forma amigável.',
  },
  {
    key: 'follow_up',
    labelKey: 'WORKFLOW.EDITOR.AI_OBJECTIVE_FOLLOW_UP',
    prompt: 'Pergunte se o cliente ainda precisa de ajuda.',
  },
  {
    key: 'reminder',
    labelKey: 'WORKFLOW.EDITOR.AI_OBJECTIVE_REMINDER',
    prompt: 'Lembre o cliente sobre o assunto em aberto.',
  },
  {
    key: 'appointment',
    labelKey: 'WORKFLOW.EDITOR.AI_OBJECTIVE_APPOINTMENT',
    prompt: 'Confirme o horário combinado com o cliente.',
  },
  {
    key: 'payment',
    labelKey: 'WORKFLOW.EDITOR.AI_OBJECTIVE_PAYMENT',
    prompt: 'Retome com o cliente sobre o pagamento pendente de forma educada.',
  },
];

export const AI_OUTREACH_TONES = [
  { key: 'friendly', labelKey: 'WORKFLOW.EDITOR.AI_TONE_FRIENDLY' },
  { key: 'professional', labelKey: 'WORKFLOW.EDITOR.AI_TONE_PROFESSIONAL' },
  { key: 'sales', labelKey: 'WORKFLOW.EDITOR.AI_TONE_SALES' },
  { key: 'support', labelKey: 'WORKFLOW.EDITOR.AI_TONE_SUPPORT' },
];

export const AI_OUTREACH_LANGUAGES = [
  { key: 'client', labelKey: 'WORKFLOW.EDITOR.AI_LANG_CLIENT' },
  { key: 'pt_BR', labelKey: 'WORKFLOW.EDITOR.AI_LANG_PT_BR' },
  { key: 'pt_PT', labelKey: 'WORKFLOW.EDITOR.AI_LANG_PT_PT' },
  { key: 'es', labelKey: 'WORKFLOW.EDITOR.AI_LANG_ES' },
  { key: 'en', labelKey: 'WORKFLOW.EDITOR.AI_LANG_EN' },
];

export const AI_OUTREACH_TONE_PREFIXES = {
  friendly: 'Tom amigável e próximo.',
  professional: 'Tom profissional e objetivo.',
  sales: 'Tom persuasivo, focado em conversão.',
  support: 'Tom empático, focado em resolver o problema.',
};

export const getAiOutreachObjectivePrompt = objectiveKey => {
  const objective = AI_OUTREACH_OBJECTIVES.find(o => o.key === objectiveKey);
  return objective?.prompt || AI_OUTREACH_OBJECTIVES[0].prompt;
};

export const composeAiOutreachPrompt = (
  objectiveKey = 'reengagement',
  toneKey = 'friendly',
  { includeTonePrefix = true } = {}
) => {
  const base = getAiOutreachObjectivePrompt(objectiveKey);
  if (!includeTonePrefix) return base;
  const prefix =
    AI_OUTREACH_TONE_PREFIXES[toneKey] || AI_OUTREACH_TONE_PREFIXES.friendly;
  return `${prefix} ${base}`.trim();
};

export const AI_ANALYSIS_TYPES = [
  { key: 'executive_summary', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_TYPE_EXECUTIVE_SUMMARY' },
  { key: 'service_quality', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_TYPE_SERVICE_QUALITY' },
  { key: 'sales_opportunities', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_TYPE_SALES_OPPORTUNITIES' },
  { key: 'customer_sentiment', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_TYPE_CUSTOMER_SENTIMENT' },
  { key: 'next_action', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_TYPE_NEXT_ACTION' },
];

export const AI_ANALYSIS_DEFAULTS = {
  analysis_types: ['full_analysis'],
  output_destination: 'private_note',
  note_prefix: '',
  whatsapp_inbox_id: '',
  whatsapp_phone: '',
  language: 'client',
};

export const AI_OUTREACH_DEFAULTS = {
  objective_preset: 'reengagement',
  tone_preset: 'friendly',
  language: 'client',
  prompt: getAiOutreachObjectivePrompt('reengagement'),
  prompt_customized: false,
  include_last_messages: true,
};

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

/** LogicFlow snap step (px). Smaller = smoother drag. */
export const WORKFLOW_CANVAS_GRID_SIZE = 10;
