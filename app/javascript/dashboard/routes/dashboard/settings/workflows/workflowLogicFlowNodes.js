import { HtmlNode, HtmlNodeModel } from '@logicflow/core';

const NODE_META = {
  trigger: {
    title: 'Gatilho',
    color: '#2563EB',
    iconPath:
      'M13 10V3L4 14h7v7l9-11h-7z',
  },
  wait: {
    title: 'Espera',
    color: '#7C3AED',
    iconPath:
      'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  condition: {
    title: 'Condição',
    color: '#D97706',
    iconPath:
      'M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  action: {
    title: 'Ação',
    color: '#059669',
    iconPath:
      'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
  },
};

export const WORKFLOW_LF_NODE_TYPE = 'workflow-card';

/** Anchor ids: `${nodeId}_in` (left) and `${nodeId}_out` (right) — only these may be used for edges. */
export const workflowAnchorInId = nodeId => `${nodeId}_in`;
export const workflowAnchorOutId = nodeId => `${nodeId}_out`;

const escapeHtml = value =>
  String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

export const workflowNodeSubtitle = properties => {
  const data = properties || {};
  const type = data.workflowNodeType;
  switch (type) {
    case 'trigger':
      return data.event_name || '—';
    case 'wait':
      return (data.duration || '?') + ' ' + (data.unit || '');
    case 'condition': {
      const list = data.conditions || [];
      if (!list.length) return 'Sem filtros (sempre Sim)';
      return list.length + ' filtro(s)';
    }
    case 'action':
      return data.action_name || '—';
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
    this.width = 240;
    this.height = 72;
    if (this.text && typeof this.text === 'object') {
      this.text.editable = false;
      this.text.value = '';
    }
  }

  setAttributes() {
    this.width = 240;
    this.height = 72;
  }

  /** Only left (in) and right (out) anchors — flow left-to-right. Coordinates must be absolute (see HtmlNodeModel in @logicflow/core). */
  getDefaultAnchor() {
    const { x, y, width } = this;
    const w = width;
    return [
      { x: x - w / 2, y, id: `${this.id}_in`, name: 'in' },
      { x: x + w / 2, y, id: `${this.id}_out`, name: 'out' },
    ];
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
    if (sourceAnchor && sourceAnchor.id && !String(sourceAnchor.id).endsWith('_out')) {
      return false;
    }
    return true;
  }

  // Make the SVG background rect fully transparent at all states
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
    const selected = this.props.model.isSelected ? ' is-selected' : '';

    rootEl.innerHTML =
      '<div class="workflow-lf-card workflow-lf-card--' +
      escapeHtml(type) +
      selected +
      '">' +
      '<div class="workflow-lf-card__stripe" style="background:' +
      meta.color +
      '"></div>' +
      '<div class="workflow-lf-card__body">' +
      '<div class="workflow-lf-card__icon" style="background:' +
      meta.color +
      '">' +
      '<svg width="16" height="16" fill="none" stroke="white" viewBox="0 0 24 24">' +
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="' +
      meta.iconPath +
      '"/>' +
      '</svg>' +
      '</div>' +
      '<div class="workflow-lf-card__text">' +
      '<div class="workflow-lf-card__title">' +
      escapeHtml(meta.title) +
      '</div>' +
      '<div class="workflow-lf-card__subtitle">' +
      escapeHtml(subtitle) +
      '</div>' +
      '</div>' +
      '</div>' +
      '</div>';
  }

  shouldUpdate() {
    const { properties, isSelected } = this.props.model;
    const type = properties.workflowNodeType;
    const key = [
      type,
      properties.event_name,
      properties.duration,
      properties.unit,
      properties.action_name,
      (properties.action_params || []).join('\0'),
      isSelected,
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

export const getLogicFlowTheme = isDark => {
  const base = {
    rect: { ...transparentShape },
    circle: { ...transparentShape },
    polygon: { ...transparentShape },
    ellipse: { ...transparentShape },
    nodeText: { display: 'none' },
    edge: {
      stroke: isDark ? '#64748b' : '#94a3b8',
      strokeWidth: 2,
    },
    anchor: {
      stroke: isDark ? '#94a3b8' : '#64748b',
      fill: isDark ? '#1e293b' : '#ffffff',
      r: 4,
    },
    outline: {
      fill: 'none',
      stroke: '#6366f1',
      strokeWidth: 2,
    },
    grid: {
      size: 20,
      stroke: isDark ? '#334155' : '#e2e8f0',
      strokeWidth: 1,
    },
    background: {
      backgroundColor: isDark ? '#0f172a' : '#f8fafc',
    },
  };

  return base;
};
