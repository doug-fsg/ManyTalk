import { DEFAULT_WORKFLOW_GRAPH } from 'dashboard/routes/dashboard/settings/workflows/constants';
import {
  WORKFLOW_LF_NODE_TYPE,
  workflowAnchorInId,
  workflowAnchorOutId,
} from 'dashboard/routes/dashboard/settings/workflows/workflowLogicFlowNodes';
import { serializeWorkflowConditions } from 'dashboard/helper/workflowConditionHelper';

export const emptyGraph = () => JSON.parse(JSON.stringify(DEFAULT_WORKFLOW_GRAPH));

export const normalizeWorkflowGraph = graph => {
  const source = graph && typeof graph === 'object' ? graph : {};
  const normalized = {
    nodes: Array.isArray(source.nodes) ? source.nodes : [],
    edges: Array.isArray(source.edges) ? source.edges : [],
    settings: {
      ...DEFAULT_WORKFLOW_GRAPH.settings,
      ...(source.settings || {}),
    },
  };

  normalized.nodes = normalized.nodes.map((node, index) => {
    const rawData = node.data || node.properties || {};
    const data = { ...rawData };
    delete data.workflowNodeType;

    return {
      id: node.id || `node_${index}`,
      type: node.type || data.workflowNodeType || 'action',
      x: node.x != null ? node.x : (node.position && node.position.x) || 120,
      y: node.y != null ? node.y : (node.position && node.position.y) || 120,
      position: {
        x: node.x != null ? node.x : (node.position && node.position.x) || 120,
        y: node.y != null ? node.y : (node.position && node.position.y) || 120,
      },
      data,
    };
  });

  const triggers = normalized.nodes.filter(n => n.type === 'trigger');
  if (triggers.length === 0) {
    normalized.nodes.unshift(JSON.parse(JSON.stringify(DEFAULT_WORKFLOW_GRAPH.nodes[0])));
  }

  normalized.nodes.forEach(node => {
    if (!node.data || !Array.isArray(node.data.conditions)) return;
    if (node.type !== 'trigger' && node.type !== 'condition') return;
    node.data.conditions = serializeWorkflowConditions(node.data.conditions, {
      dropEmpty: true,
    });
  });

  return normalized;
};

export const graphToLogicFlowData = graph => {
  const g = graph || emptyGraph();
  const nodes = (g.nodes || []).map((node, index) => {
    const data = node.data || node.properties || {};
    const posX = node.x != null ? node.x : (node.position && node.position.x != null ? node.position.x : 100 + index * 40);
    const posY = node.y != null ? node.y : (node.position && node.position.y != null ? node.position.y : 100 + index * 60);
    return {
      id: node.id,
      type: WORKFLOW_LF_NODE_TYPE,
      x: posX,
      y: posY,
      text: '',
      properties: {
        ...data,
        workflowNodeType: node.type,
      },
    };
  });

  const edges = (g.edges || []).map(edge => ({
    id: edge.id || `e_${edge.source}_${edge.target}`,
    type: 'polyline',
    sourceNodeId: edge.source,
    targetNodeId: edge.target,
    sourceAnchorId: workflowAnchorOutId(edge.source),
    targetAnchorId: workflowAnchorInId(edge.target),
    text: edge.sourceHandle || '',
  }));

  return { nodes, edges };
};

const coerceArray = value => {
  if (Array.isArray(value)) return value;
  if (value && typeof value === 'object') return Object.values(value);
  return [];
};

export const logicFlowDataToGraph = (lfData, settings = {}) => {
  const lfNodes = coerceArray(lfData && lfData.nodes);
  const nodes = lfNodes.map(node => {
    // LF 1.x can expose properties either as node.properties or node.property (internal)
    const props = node.properties || node.property || {};
    const workflowType = props.workflowNodeType || 'action';
    const data = { ...props };
    delete data.workflowNodeType;
    return {
      id: node.id,
      type: workflowType,
      x: node.x,
      y: node.y,
      position: { x: node.x, y: node.y },
      data,
    };
  });

  const lfEdges = coerceArray(lfData && lfData.edges);
  const edges = lfEdges.map(edge => ({
    id: edge.id,
    source: edge.sourceNodeId,
    target: edge.targetNodeId,
    sourceHandle: edge.text || undefined,
  }));

  return {
    nodes,
    edges,
    settings: settings || DEFAULT_WORKFLOW_GRAPH.settings,
  };
};

const nodeLabel = node => {
  const data = node.data || node.properties || {};
  switch (node.type) {
    case 'trigger':
      return `Gatilho: ${data.event_name || '—'}`;
    case 'wait':
      return `Espera ${data.duration || '?'} ${data.unit || ''}`;
    case 'condition':
      return 'Condição';
    case 'action':
      return `Ação: ${data.action_name || '—'}`;
    default:
      return node.type;
  }
};

export const nextNodeId = () => `node_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;

/** Stable string for comparing graph snapshots (avoids unnecessary canvas re-renders). */
export const workflowGraphSnapshot = graph =>
  JSON.stringify(normalizeWorkflowGraph(graph));

/** Plain object safe for axios JSON (strips Vue reactivity). */
export const serializeGraphForApi = graph =>
  JSON.parse(JSON.stringify(normalizeWorkflowGraph(graph)));

export const exportGraphFromLogicFlow = (lf, fallbackGraph) => {
  if (!lf) return normalizeWorkflowGraph(fallbackGraph);
  try {
    const raw =
      typeof lf.getGraphRawData === 'function'
        ? lf.getGraphRawData()
        : lf.getGraphData();
    const settings =
      (fallbackGraph && fallbackGraph.settings) || undefined;
    return normalizeWorkflowGraph(logicFlowDataToGraph(raw, settings));
  } catch (e) {
    return normalizeWorkflowGraph(fallbackGraph);
  }
};
