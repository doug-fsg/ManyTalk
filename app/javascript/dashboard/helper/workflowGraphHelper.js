import { DEFAULT_WORKFLOW_GRAPH } from 'dashboard/routes/dashboard/settings/workflows/constants';
import {
  WORKFLOW_LF_NODE_TYPE,
  workflowAnchorInId,
  workflowAnchorOutId,
  sourceHandleToAnchorId,
  anchorIdToSourceHandle,
  sourceHandleLabel,
  isBranchNodeType,
} from 'dashboard/routes/dashboard/settings/workflows/workflowLogicFlowNodes';
import { WORKFLOW_EDGE_TYPE } from 'dashboard/routes/dashboard/settings/workflows/workflowLogicFlowEdges';
import { serializeWorkflowConditions } from 'dashboard/helper/workflowConditionHelper';
import {
  normalizeActionsList,
  syncActionNodeFields,
} from 'dashboard/routes/dashboard/settings/workflows/workflowActionHelpers';

export const emptyGraph = () => JSON.parse(JSON.stringify(DEFAULT_WORKFLOW_GRAPH));

const nodeTypeById = (nodes, nodeId) => {
  const node = (nodes || []).find(n => n.id === nodeId);
  return node?.type || node?.data?.workflowNodeType;
};

const NODE_LAYOUT_WIDTH = 128;
const NODE_LAYOUT_H_GAP = 56;
const NODE_LAYOUT_H_STEP = NODE_LAYOUT_WIDTH + NODE_LAYOUT_H_GAP;
const NODE_LAYOUT_V_STEP = 120;
const NODE_LAYOUT_START_X = 120;
const NODE_LAYOUT_START_Y = 120;

const nodeHasExplicitPosition = node =>
  node.x != null ||
  node.y != null ||
  (node.position &&
    (node.position.x != null || node.position.y != null));

const applyLinearLayoutFromTrigger = (normalized, shouldAutoLayout = true) => {
  const { nodes, edges } = normalized;
  if (!nodes.length || !shouldAutoLayout) return;

  const trigger = nodes.find(node => node.type === 'trigger');
  if (!trigger) return;

  const adjacency = {};
  (edges || []).forEach(edge => {
    if (!adjacency[edge.source]) adjacency[edge.source] = [];
    adjacency[edge.source].push(edge.target);
  });

  const layoutMeta = new Map();
  const visited = new Set();

  const visit = (nodeId, depth, row) => {
    if (visited.has(nodeId)) return;
    visited.add(nodeId);
    layoutMeta.set(nodeId, { depth, row });

    const children = adjacency[nodeId] || [];
    children.forEach((childId, index) => {
      visit(childId, depth + 1, row + index);
    });
  };

  visit(trigger.id, 0, 0);

  let extraDepth =
    Math.max(...[...layoutMeta.values()].map(meta => meta.depth), 0) + 1;
  nodes.forEach(node => {
    if (visited.has(node.id)) return;
    layoutMeta.set(node.id, { depth: extraDepth, row: 0 });
    extraDepth += 1;
  });

  normalized.nodes = nodes.map(node => {
    const meta = layoutMeta.get(node.id) || { depth: 0, row: 0 };
    const x = NODE_LAYOUT_START_X + meta.depth * NODE_LAYOUT_H_STEP;
    const y = NODE_LAYOUT_START_Y + meta.row * NODE_LAYOUT_V_STEP;
    return {
      ...node,
      x,
      y,
      position: { x, y },
    };
  });
};

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

  const sourceNodes = Array.isArray(source.nodes) ? source.nodes : [];
  const shouldAutoLayout = sourceNodes.some(node => !nodeHasExplicitPosition(node));

  normalized.nodes = normalized.nodes.map((node, index) => {
    const rawData = node.data || node.properties || {};
    const data = { ...rawData };
    delete data.workflowNodeType;
    const type = node.type || data.workflowNodeType || 'action';
    if (type === 'action') {
      Object.assign(data, syncActionNodeFields(normalizeActionsList(data)));
    }

    return {
      id: node.id || `node_${index}`,
      type,
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

  applyLinearLayoutFromTrigger(normalized, shouldAutoLayout);

  // Coerce any sourceHandle stored as a LogicFlow text object { x, y, value } to its
  // string value. This can happen when an older save went through with the text-object bug.
  normalized.edges.forEach(edge => {
    if (edge.sourceHandle && typeof edge.sourceHandle === 'object') {
      edge.sourceHandle = edge.sourceHandle.value || undefined;
    }
  });

  // Pass 1: Fix cross-type handle contamination (e.g. 'true'/'false' on wait_for_reply,
  // or 'replied'/'timeout' on condition). Can happen when a node type changes or when
  // an edge is deserialized with the wrong context. forEach iterates object references
  // so mutating `edge` directly updates the array element in place.
  normalized.edges.forEach(edge => {
    const srcType = nodeTypeById(normalized.nodes, edge.source);
    if (!isBranchNodeType(srcType) || !edge.sourceHandle) return;
    if (srcType === 'wait_for_reply') {
      if (edge.sourceHandle === 'true') edge.sourceHandle = 'replied';
      else if (edge.sourceHandle === 'false') edge.sourceHandle = 'timeout';
    } else if (srcType === 'ai_wait_for_intent') {
      if (edge.sourceHandle === 'true') edge.sourceHandle = 'intent_detected';
      else if (edge.sourceHandle === 'false') edge.sourceHandle = 'timeout';
      else if (edge.sourceHandle === 'replied') edge.sourceHandle = 'intent_detected';
    } else if (srcType === 'condition') {
      if (edge.sourceHandle === 'replied') edge.sourceHandle = 'true';
      else if (edge.sourceHandle === 'timeout') edge.sourceHandle = 'false';
      else if (edge.sourceHandle === 'intent_detected') edge.sourceHandle = 'true';
    }
  });

  // Pass 2: Assign default sourceHandle for branch edges that are still missing handles
  const branchEdgesBySource = {};
  normalized.edges.forEach((edge, index) => {
    const srcType = nodeTypeById(normalized.nodes, edge.source);
    if (!isBranchNodeType(srcType)) return;
    if (edge.sourceHandle) return;
    if (!branchEdgesBySource[edge.source]) branchEdgesBySource[edge.source] = [];
    branchEdgesBySource[edge.source].push(index);
  });
  Object.values(branchEdgesBySource).forEach(indices => {
    indices.forEach((edgeIndex, i) => {
      const srcType = nodeTypeById(normalized.nodes, normalized.edges[edgeIndex].source);
      if (srcType === 'wait_for_reply') {
        normalized.edges[edgeIndex].sourceHandle = i === 0 ? 'replied' : 'timeout';
      } else if (srcType === 'ai_wait_for_intent') {
        normalized.edges[edgeIndex].sourceHandle = i === 0 ? 'intent_detected' : 'timeout';
      } else {
        normalized.edges[edgeIndex].sourceHandle = i === 0 ? 'true' : 'false';
      }
    });
  });

  return normalized;
};

export const graphToLogicFlowData = graph => {
  const g = normalizeWorkflowGraph(graph);
  const nodes = (g.nodes || []).map((node, index) => {
    const data = node.data || node.properties || {};
    const posX =
      node.x != null
        ? node.x
        : node.position && node.position.x != null
          ? node.position.x
          : 100 + index * 40;
    const posY =
      node.y != null
        ? node.y
        : node.position && node.position.y != null
          ? node.position.y
          : 100 + index * 60;
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

  const edges = (g.edges || []).map(edge => {
    const srcType = nodeTypeById(g.nodes, edge.source);
    const sourceHandle = edge.sourceHandle;
    return {
      id: edge.id || `e_${edge.source}_${edge.target}_${sourceHandle || 'default'}`,
      type: WORKFLOW_EDGE_TYPE,
      sourceNodeId: edge.source,
      targetNodeId: edge.target,
      sourceAnchorId: sourceHandleToAnchorId(edge.source, sourceHandle, srcType),
      targetAnchorId: workflowAnchorInId(edge.target),
      text: sourceHandleLabel(sourceHandle, srcType) || sourceHandle || '',
    };
  });

  return { nodes, edges };
};

const coerceArray = value => {
  if (Array.isArray(value)) return value;
  if (value && typeof value === 'object') return Object.values(value);
  return [];
};

export const logicFlowDataToGraph = (lfData, settings = {}) => {
  const lfNodes = coerceArray(lfData && lfData.nodes);
  const nodeTypeMap = {};
  lfNodes.forEach(node => {
    const props = node.properties || node.property || {};
    nodeTypeMap[node.id] = props.workflowNodeType || 'action';
  });

  const nodes = lfNodes.map(node => {
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
  const edges = lfEdges.map(edge => {
    const srcType = nodeTypeMap[edge.sourceNodeId];
    // LogicFlow stores edge text as { x, y, value } when the label has a position.
    // Always extract the string value before using it as a sourceHandle.
    const rawText = edge.text;
    const textValue =
      rawText && typeof rawText === 'object' ? rawText.value : rawText;

    let sourceHandle =
      anchorIdToSourceHandle(edge.sourceAnchorId, srcType) ||
      textValue ||
      undefined;
    if (sourceHandle === 'Respondeu') sourceHandle = 'replied';
    if (sourceHandle === 'Sem resposta') sourceHandle = 'timeout';
    if (sourceHandle === 'Então') sourceHandle = 'true';
    if (sourceHandle === 'Senão') sourceHandle = 'false';
    // Correct cross-type handle contamination when srcType is known
    if (srcType === 'wait_for_reply') {
      if (sourceHandle === 'true') sourceHandle = 'replied';
      else if (sourceHandle === 'false') sourceHandle = 'timeout';
    } else if (srcType === 'condition') {
      if (sourceHandle === 'replied') sourceHandle = 'true';
      else if (sourceHandle === 'timeout') sourceHandle = 'false';
    }

    return {
      id: edge.id,
      source: edge.sourceNodeId,
      target: edge.targetNodeId,
      sourceHandle,
    };
  });

  return {
    nodes,
    edges,
    settings: settings || DEFAULT_WORKFLOW_GRAPH.settings,
  };
};

export const nextNodeId = () => `node_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;

export const workflowGraphSnapshot = graph =>
  JSON.stringify(normalizeWorkflowGraph(graph));

export const serializeGraphForApi = graph =>
  JSON.parse(JSON.stringify(normalizeWorkflowGraph(graph)));

export const extractInvalidNodeIds = errors => {
  const ids = new Set();
  (errors || []).forEach(error => {
    if (error && typeof error === 'object' && error.node_id) {
      ids.add(error.node_id);
      return;
    }
    const message = typeof error === 'string' ? error : error?.message;
    if (!message) return;
    const nodeMatch = message.match(/Node ([\w-]+)/);
    if (nodeMatch) ids.add(nodeMatch[1]);
  });
  return [...ids];
};

export const validationErrorMessages = errors =>
  normalizeValidationErrors(errors).map(item => item.message);

export const normalizeValidationErrors = errors =>
  (errors || []).map(error => {
    if (typeof error === 'string') {
      const nodeMatch = error.match(/Node ([\w-]+)/);
      return {
        message: error,
        node_id: nodeMatch ? nodeMatch[1] : null,
      };
    }

    return {
      message: error?.message || String(error),
      node_id: error?.node_id || null,
    };
  });

export const exportGraphFromLogicFlow = (lf, fallbackGraph) => {
  if (!lf) return normalizeWorkflowGraph(fallbackGraph);
  try {
    const raw =
      typeof lf.getGraphRawData === 'function'
        ? lf.getGraphRawData()
        : lf.getGraphData();
    const settings = (fallbackGraph && fallbackGraph.settings) || undefined;
    return normalizeWorkflowGraph(logicFlowDataToGraph(raw, settings));
  } catch (e) {
    return normalizeWorkflowGraph(fallbackGraph);
  }
};
