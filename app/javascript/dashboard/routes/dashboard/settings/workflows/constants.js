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
  OPERATOR_TYPES_DATE,
  REPLY_CONDITION_OPERATORS,
} from '../automation/operators';

export const WORKFLOW_REPLY_CONDITION_KEYS = [
  'contact_replied_since_baseline',
  'contact_not_replied_since_baseline',
];

/** Event key for mid-flow condition nodes (merged v1 attributes + extras). */
export const WORKFLOW_FLOW_EVENT_KEY = 'workflow_flow';

const WORKFLOW_EXTRA_CONDITIONS = [
  {
    key: 'labels',
    name: 'Etiqueta',
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
    filterOperators: OPERATOR_TYPES_DATE,
  },
  {
    key: 'last_activity_at',
    name: 'Última atividade',
    attributeI18nKey: 'LAST_ACTIVITY',
    inputType: 'date',
    filterOperators: OPERATOR_TYPES_DATE,
  },
  {
    key: 'contact_replied_since_baseline',
    name: 'Cliente respondeu',
    attributeI18nKey: 'CONTACT_REPLIED',
    inputType: 'search_select',
    filterOperators: REPLY_CONDITION_OPERATORS,
  },
  {
    key: 'contact_not_replied_since_baseline',
    name: 'Cliente não respondeu',
    attributeI18nKey: 'CONTACT_NOT_REPLIED',
    inputType: 'search_select',
    filterOperators: REPLY_CONDITION_OPERATORS,
  },
];

let cachedWorkflowAutomationTypes = null;

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

/** Cached singleton — avoids deep-cloning AUTOMATIONS on every conditions editor mount. */
export const getWorkflowAutomationTypes = () => {
  if (!cachedWorkflowAutomationTypes) {
    cachedWorkflowAutomationTypes = buildWorkflowAutomationTypes();
  }
  return cachedWorkflowAutomationTypes;
};

export const resetWorkflowAutomationTypesCache = () => {
  cachedWorkflowAutomationTypes = null;
};

export const WORKFLOW_TRIGGER_EVENTS = [
  ...AUTOMATION_RULE_EVENTS,
  { key: 'manual', value: 'Início manual (pela conversa)' },
  { key: 'contact_kanban_stage_changed', value: 'Estágio do CRM alterado' },
  { key: 'contact_kanban_stage_idle', value: 'Parado no estágio do CRM (sem atividade)' },
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
  {
    group: 'Inteligencia Artificial',
    type: 'ai_wait_for_intent',
    label: 'Aguardar intenção',
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
  analysis_types: ['executive_summary'],
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

export const AI_INTENT_CATALOG = [
  {
    key: 'schedule_visit',
    label: 'Agendar visita',
    description: 'Cliente quer marcar visita, horário ou reunião',
    examples: ['quero agendar', 'tem horário disponível', 'pode marcar uma visita'],
  },
  {
    key: 'quote_request',
    label: 'Pedido de orçamento',
    description: 'Cliente pede proposta, cotação ou preço',
    examples: ['quero um orçamento', 'quanto custa', 'manda a proposta'],
  },
  {
    key: 'technical_support',
    label: 'Suporte técnico',
    description: 'Cliente relata problema técnico ou pede ajuda',
    examples: ['não funciona', 'preciso de suporte', 'está com erro'],
  },
  {
    key: 'cancellation',
    label: 'Cancelamento',
    description: 'Cliente quer cancelar pedido, serviço ou contrato',
    examples: ['quero cancelar', 'cancela meu pedido', 'não quero mais'],
  },
  {
    key: 'payment_confirmed',
    label: 'Pagamento confirmado',
    description: 'Cliente informa que já pagou ou enviou comprovante',
    examples: ['já paguei', 'fiz o pix', 'enviei o comprovante'],
  },
  {
    key: 'product_info',
    label: 'Informações do produto',
    description: 'Cliente quer detalhes sobre produto ou serviço',
    examples: ['como funciona', 'quais as opções', 'tem em estoque'],
  },
  {
    key: 'order_status',
    label: 'Status do pedido',
    description: 'Cliente pergunta andamento de pedido ou entrega',
    examples: ['cadê meu pedido', 'já saiu para entrega', 'qual o status'],
  },
  {
    key: 'human_agent',
    label: 'Falar com atendente',
    description: 'Cliente pede atendimento humano',
    examples: ['quero falar com alguém', 'atendente', 'pessoa real'],
  },
  {
    key: 'complaint',
    label: 'Reclamação',
    description: 'Cliente expressa insatisfação ou reclama',
    examples: ['quero reclamar', 'péssimo atendimento', 'não resolveu'],
  },
  {
    key: 'purchase_intent',
    label: 'Intenção de compra',
    description: 'Cliente demonstra interesse em comprar',
    examples: ['quero comprar', 'vou fechar', 'pode reservar'],
  },
  {
    key: 'delivery_question',
    label: 'Dúvida sobre entrega',
    description: 'Cliente pergunta prazo, frete ou endereço de entrega',
    examples: ['quando chega', 'frete grátis', 'entrega hoje'],
  },
  {
    key: 'reschedule',
    label: 'Remarcar',
    description: 'Cliente quer alterar data ou horário já combinado',
    examples: ['preciso remarcar', 'muda o horário', 'outro dia'],
  },
  {
    key: 'confirmation',
    label: 'Confirmação',
    description: 'Cliente confirma presença, pedido ou acordo',
    examples: ['confirmo', 'pode confirmar', 'estarei lá'],
  },
  {
    key: 'catalog_request',
    label: 'Ver catálogo',
    description: 'Cliente quer ver opções, lista ou portfólio',
    examples: ['manda o catálogo', 'quais opções', 'ver produtos'],
  },
  {
    key: 'contract_question',
    label: 'Dúvida contratual',
    description: 'Cliente pergunta sobre contrato, plano ou termos',
    examples: ['como funciona o plano', 'qual o contrato', 'renovação'],
  },
  {
    key: 'documentation_request',
    label: 'Solicitar documentação',
    description: 'Cliente pede nota fiscal, boleto ou documento',
    examples: ['manda a nota', 'preciso do boleto', 'documentação'],
  },
  {
    key: 'menu_request',
    label: 'Ver catálogo',
    description: 'Cliente quer ver opções, menu ou portfólio',
    examples: ['quero o cardápio', 'manda o menu', 'ver opções'],
  },
];

export const findWorkflowIntentByKey = key =>
  AI_INTENT_CATALOG.find(intent => intent.key === key);

export const searchWorkflowIntents = (query, limit = 8) => {
  const normalized = String(query || '')
    .trim()
    .toLowerCase();
  if (!normalized) return AI_INTENT_CATALOG.slice(0, limit);

  return AI_INTENT_CATALOG.filter(intent => {
    const haystack = [
      intent.label,
      intent.description,
      intent.key,
      ...(intent.examples || []),
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(normalized);
  }).slice(0, limit);
};

export const AI_WAIT_FOR_INTENT_DEFAULTS = {
  intent_key: '',
  intent_description: '',
  duration: 30,
  unit: 'minutes',
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
    cancel_on_contact_reply: false,
    pause_on_contact_reply: true,
    cancel_on_conversation_resolved: true,
    allow_manual_start_only: false,
    enroll_latest_conversation_only: true,
    enrollment_scope: 'contact',
    respect_business_hours: true,
  },
};

export const logicFlowNodeType = () => 'workflow-card';

/** LogicFlow snap step (px). Smaller = smoother drag. */
export const WORKFLOW_CANVAS_GRID_SIZE = 10;
