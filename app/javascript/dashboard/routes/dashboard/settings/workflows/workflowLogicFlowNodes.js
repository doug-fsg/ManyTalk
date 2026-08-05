import { HtmlNode, HtmlNodeModel } from '@logicflow/core';
import { WORKFLOW_CANVAS_GRID_SIZE, findWorkflowIntentByKey } from './constants';
import {
  TRIGGER_EVENT_LABELS,
  FORM_SUBMITTED_EVENT_KEY,
  extractFormIdsFromConditions,
} from './workflowExtensions';

const NODE_META = {
  trigger: {
    title: 'Gatilho',
    color: '#2563EB',
    iconPath: 'M13 10V3L4 14h7v7l9-11h-7z',
  },
  wait: {
    title: 'Espera',
    color: '#0D9488',
    iconPath: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  wait_for_reply: {
    title: 'Aguardar resposta',
    color: '#0D9488',
    iconPath:
      'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z M8 12h.01M12 12h.01M16 12h.01',
  },
  condition: {
    title: 'Se (IF)',
    color: '#D97706',
    iconPath:
      'M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  action: {
    title: 'Ação',
    color: '#059669',
    iconPath: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  ai_conversation_analysis: {
    title: 'Avaliar Conversa',
    color: '#7C3AED',
    iconPath:
      'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.847a4.5 4.5 0 003.09 3.09L15.75 12l-2.847.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z',
  },
  ai_outreach: {
    title: 'Chamar cliente',
    color: '#7C3AED',
    iconPath:
      'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.847a4.5 4.5 0 003.09 3.09L15.75 12l-2.847.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z',
  },
  ai_wait_for_intent: {
    title: 'Aguardar intenção',
    color: '#7C3AED',
    iconPath:
      'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.847a4.5 4.5 0 003.09 3.09L15.75 12l-2.847.813a4.5 4.5 0 00-3.09 3.09zM12 8v4l3 3',
  },
};

export const getWorkflowNodeVisual = type => {
  const meta = NODE_META[type] || NODE_META.action;
  return { bg: meta.color, icon: meta.iconPath, title: meta.title };
};

export const WORKFLOW_LF_NODE_TYPE = 'workflow-card';

const AI_OBJECTIVE_SHORT = {
  reengagement: 'Reengajar',
  follow_up: 'Cobrar retorno',
  reminder: 'Lembrete',
  appointment: 'Agendamento',
  payment: 'Cobrança',
};

const AI_TONE_SHORT = {
  friendly: 'Amigável',
  professional: 'Profissional',
  sales: 'Vendas',
  support: 'Suporte',
};

/** Compact n8n-like card — levemente retangular */
export const WORKFLOW_NODE_WIDTH = 128;
export const WORKFLOW_NODE_HEIGHT = 84;
export const WORKFLOW_BRANCH_NODE_HEIGHT = 84;

let workflowCanvasDarkMode =
  typeof document !== 'undefined' &&
  (document.body.classList.contains('dark') ||
    document.documentElement.classList.contains('dark'));

export const setWorkflowCanvasDarkMode = isDark => {
  workflowCanvasDarkMode = Boolean(isDark);
};

export const isWorkflowCanvasDark = () => workflowCanvasDarkMode;

const workflowNodeHeight = isBranch =>
  isBranch ? WORKFLOW_BRANCH_NODE_HEIGHT : WORKFLOW_NODE_HEIGHT;

export const BRANCH_NODE_TYPES = ['condition', 'wait_for_reply', 'ai_wait_for_intent'];

export const isBranchNodeType = type => BRANCH_NODE_TYPES.includes(type);

export const workflowAnchorInId = nodeId => `${nodeId}_in`;
export const workflowAnchorOutId = nodeId => `${nodeId}_out`;
export const workflowAnchorOutTrueId = nodeId => `${nodeId}_out_true`;
export const workflowAnchorOutFalseId = nodeId => `${nodeId}_out_false`;

/** Maps graph sourceHandle to LogicFlow source anchor id. */
export const sourceHandleToAnchorId = (nodeId, sourceHandle, nodeType) => {
  if (!isBranchNodeType(nodeType)) {
    return workflowAnchorOutId(nodeId);
  }
  const handle = String(sourceHandle || '');
  if (nodeType === 'wait_for_reply') {
    if (handle === 'replied') return workflowAnchorOutTrueId(nodeId);
    if (handle === 'timeout') return workflowAnchorOutFalseId(nodeId);
  }
  if (nodeType === 'ai_wait_for_intent') {
    if (handle === 'intent_detected') return workflowAnchorOutTrueId(nodeId);
    if (handle === 'timeout') return workflowAnchorOutFalseId(nodeId);
  }
  if (handle === 'true' || handle === 'replied' || handle === 'intent_detected') return workflowAnchorOutTrueId(nodeId);
  if (handle === 'false' || handle === 'timeout') return workflowAnchorOutFalseId(nodeId);
  return workflowAnchorOutTrueId(nodeId);
};

/** Maps LogicFlow source anchor id back to graph sourceHandle. */
export const anchorIdToSourceHandle = (anchorId, nodeType) => {
  const id = String(anchorId || '');
  if (id.endsWith('_out_true')) {
    if (nodeType === 'wait_for_reply') return 'replied';
    if (nodeType === 'ai_wait_for_intent') return 'intent_detected';
    return 'true';
  }
  if (id.endsWith('_out_false')) {
    return nodeType === 'wait_for_reply' || nodeType === 'ai_wait_for_intent' ? 'timeout' : 'false';
  }
  return undefined;
};

export const sourceHandleLabel = (sourceHandle, nodeType) => {
  if (nodeType === 'wait_for_reply') {
    if (sourceHandle === 'replied') return 'Respondeu';
    if (sourceHandle === 'timeout') return 'Sem resposta';
  }
  if (nodeType === 'ai_wait_for_intent') {
    if (sourceHandle === 'intent_detected') return 'Detectada';
    if (sourceHandle === 'timeout') return 'Prazo';
  }
  if (sourceHandle === 'true') return 'Então';
  if (sourceHandle === 'false') return 'Senão';
  return '';
};

const escapeHtml = value =>
  String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

export const workflowNodeSubtitle = properties => {
  const data = properties || {};
  if (data.label) return data.label;
  const type = data.workflowNodeType;
  switch (type) {
    case 'trigger': {
      if (data.event_name === FORM_SUBMITTED_EVENT_KEY) {
        const count = extractFormIdsFromConditions(data.conditions || []).length;
        if (count > 0) return `${TRIGGER_EVENT_LABELS[data.event_name]} · ${count} formulário(s)`;
      }
      return TRIGGER_EVENT_LABELS[data.event_name] || data.event_name || '—';
    }
    case 'wait':
      return `${data.duration || '?'} ${data.unit || ''}`;
    case 'wait_for_reply':
      return data.label || `${data.duration || '?'} ${data.unit || ''}`;
    case 'condition': {
      const list = data.conditions || [];
      if (!list.length) return 'Sem filtros (sempre Então)';
      return `${list.length} filtro(s)`;
    }
    case 'action':
      return data.action_name || '—';
    case 'ai_outreach': {
      const obj = AI_OBJECTIVE_SHORT[data.objective_preset] || 'IA';
      const tone = AI_TONE_SHORT[data.tone_preset] || '';
      return tone ? `${obj} · ${tone}` : obj;
    }
    case 'ai_conversation_analysis': {
      const type = (data.analysis_types && data.analysis_types[0]) || 'full_analysis';
      const dest = data.output_destination === 'whatsapp_external' ? 'WhatsApp' : 'Nota privada';
      const TYPE_LABELS = {
        full_analysis: 'Completa',
        executive_summary: 'Resumo',
        service_quality: 'Qualidade',
        sales_opportunities: 'Oportunidades',
        customer_sentiment: 'Sentimento',
        next_action: 'Próx. ação',
      };
      return `${TYPE_LABELS[type] || type} · ${dest}`;
    }
    case 'ai_wait_for_intent': {
      const label = data.intent_key
        ? findWorkflowIntentByKey(data.intent_key)?.label
        : null;
      const intentPart = label || (data.intent_key ? data.intent_key : '—');
      return `${intentPart} · ${data.duration || '?'}${data.unit ? data.unit[0] : ''}`;
    }
    default:
      return type || '';
  }
};

const TRANSPARENT = {
  fill: 'transparent',
  stroke: 'transparent',
  strokeWidth: 0,
  fillOpacity: 0,
};

class WorkflowCardModel extends HtmlNodeModel {
  initNodeData(data) {
    if (data.text === undefined || data.text === null) {
      data.text = '';
    }
    super.initNodeData(data);
    this.width = WORKFLOW_NODE_WIDTH;
    this.height = workflowNodeHeight(this.isBranchNode());
    if (this.text && typeof this.text === 'object') {
      this.text.editable = false;
      this.text.value = '';
    }
  }

  isBranchNode() {
    const wt = this.properties && this.properties.workflowNodeType;
    return isBranchNodeType(wt);
  }

  setAttributes() {
    this.width = WORKFLOW_NODE_WIDTH;
    this.height = workflowNodeHeight(this.isBranchNode());
  }

  getDefaultAnchor() {
    const { x, y, width, height } = this;
    const w = width;
    const anchors = [{ x: x - w / 2, y, id: `${this.id}_in`, name: 'in' }];

    if (this.isBranchNode()) {
      const offsetY = height / 4;
      anchors.push(
        { x: x + w / 2, y: y - offsetY, id: `${this.id}_out_true`, name: 'out_true' },
        { x: x + w / 2, y: y + offsetY, id: `${this.id}_out_false`, name: 'out_false' }
      );
    } else {
      anchors.push({ x: x + w / 2, y, id: `${this.id}_out`, name: 'out' });
    }

    return anchors;
  }

  isAllowConnectedAsTarget(source, sourceAnchor, targetAnchor) {
    const wt = this.properties && this.properties.workflowNodeType;
    if (wt === 'trigger') return false;
    if (targetAnchor && targetAnchor.id && !String(targetAnchor.id).endsWith('_in')) {
      return false;
    }
    return true;
  }

  isAllowConnectedAsSource(target, sourceAnchor, targetAnchor) {
    if (!sourceAnchor || !sourceAnchor.id) return true;
    const id = String(sourceAnchor.id);
    return (
      id.endsWith('_out') ||
      id.endsWith('_out_true') ||
      id.endsWith('_out_false')
    );
  }

  getNodeStyle() {
    return { ...TRANSPARENT };
  }

  getOutlineStyle() {
    return { ...TRANSPARENT };
  }

  getHoverStyle() {
    return { ...TRANSPARENT };
  }

  getSelectedStyle() {
    return { ...TRANSPARENT };
  }
}

class WorkflowCardView extends HtmlNode {
  setHtml(rootEl) {
    const { properties } = this.props.model;
    const type = properties.workflowNodeType || 'action';
    const meta = NODE_META[type] || NODE_META.action;
    const subtitle = workflowNodeSubtitle(properties);
    const invalidClass = properties.isInvalid ? ' is-invalid' : '';
    const selected = this.props.model.isSelected ? ' is-selected' : '';
    const themeClass = isWorkflowCanvasDark() ? ' is-dark' : '';
    const branchClass = isBranchNodeType(type) ? ' workflow-lf-card--branch' : '';

    rootEl.innerHTML =
      `<div class="workflow-lf-card workflow-lf-card--n8n workflow-lf-card--${escapeHtml(type)}${branchClass}${selected}${invalidClass}${themeClass}">` +
      '<div class="workflow-lf-card__content">' +
      `<div class="workflow-lf-card__icon" style="background:${meta.color}">` +
      '<svg width="16" height="16" fill="none" stroke="white" viewBox="0 0 24 24">' +
      `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${meta.iconPath}"/>` +
      '</svg></div>' +
      `<div class="workflow-lf-card__title">${escapeHtml(meta.title)}</div>` +
      `<div class="workflow-lf-card__subtitle">${escapeHtml(subtitle)}</div>` +
      '</div></div>';
  }

  shouldUpdate() {
    const { properties, isSelected } = this.props.model;
    const type = properties.workflowNodeType;
    const key = [
      type,
      properties.label,
      properties.event_name,
      properties.duration,
      properties.unit,
      properties.action_name,
      properties.objective_preset,
      properties.tone_preset,
      properties.intent_key,
      (properties.conditions || []).length,
      (properties.action_params || []).join('\0'),
      properties.isInvalid,
      isSelected,
      isWorkflowCanvasDark(),
    ].join('|');
    if (this._renderKey === key) return false;
    this._renderKey = key;
    return true;
  }
}

export const registerWorkflowNodes = lf => {
  lf.register({
    type: WORKFLOW_LF_NODE_TYPE,
    view: WorkflowCardView,
    model: WorkflowCardModel,
  });
};

const transparentShape = {
  fill: 'transparent',
  stroke: 'transparent',
  strokeWidth: 0,
};

export const getLogicFlowTheme = isDark => ({
  rect: { ...transparentShape },
  circle: { ...transparentShape },
  polygon: { ...transparentShape },
  ellipse: { ...transparentShape },
  nodeText: { display: 'none' },
  edge: {
    stroke: isDark ? 'rgba(226, 232, 240, 0.38)' : '#c0c5ce',
    strokeWidth: 2,
    hoverStroke: isDark ? 'rgba(248, 250, 252, 0.55)' : '#94a3b8',
    selectedStroke: isDark ? 'rgba(255, 255, 255, 0.65)' : '#6366f1',
  },
  // Anchor dots: visible small circles like n8n (show on node hover via CSS).
  anchor: {
    stroke: isDark ? '#64748b' : '#94a3b8',
    fill: isDark ? '#1e293b' : '#ffffff',
    r: 5,
    hover: {
      fill: '#3b82f6',
      stroke: '#3b82f6',
      r: 6,
    },
  },
  outline: {
    fill: 'none',
    stroke: '#6366f1',
    strokeWidth: 2,
  },
  grid: {
    size: WORKFLOW_CANVAS_GRID_SIZE,
    stroke: isDark ? 'rgba(148, 163, 184, 0.05)' : 'rgba(148, 163, 184, 0.04)',
    strokeWidth: 1,
  },
  background: {
    backgroundColor: isDark ? '#0f172a' : '#f4f6f8',
  },
});
