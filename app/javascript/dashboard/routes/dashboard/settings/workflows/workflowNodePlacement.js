import { WORKFLOW_CANVAS_GRID_SIZE } from './constants';
import {
  WORKFLOW_NODE_WIDTH,
  WORKFLOW_NODE_HEIGHT,
  isBranchNodeType,
  workflowAnchorOutId,
  workflowAnchorOutTrueId,
  workflowAnchorOutFalseId,
} from './workflowLogicFlowNodes';

export const NODE_INSERT_GAP_X = 96;
export const NODE_INSERT_GAP_Y = 56;
/** Graph-space length of the n8n-style dangling stub before the "+" */
export const NODE_STUB_LENGTH = 36;
const COLLISION_DISTANCE = 56;
const MAX_COLLISION_NUDGES = 14;
const CONNECT_DRAG_THRESHOLD_PX = 6;
/** Graph-space radius to snap drop onto a node's input port */
export const CONNECT_SNAP_DISTANCE = 96;
/** Extra padding around node body when hit-testing drop targets */
export const CONNECT_NODE_HIT_PAD = 40;

export const CONNECT_DRAG_THRESHOLD = CONNECT_DRAG_THRESHOLD_PX;

export const snapToGrid = (value, grid = WORKFLOW_CANVAS_GRID_SIZE) =>
  Math.round(Number(value) / grid) * grid;

/** LogicFlow expects client (viewport) coords; returns canvas graph point. */
export const clientToCanvasPoint = (lf, clientX, clientY) => {
  if (!lf || !Number.isFinite(clientX) || !Number.isFinite(clientY)) return null;

  const getPointByClient =
    typeof lf.getPointByClient === 'function'
      ? lf.getPointByClient.bind(lf)
      : typeof lf.graphModel?.getPointByClient === 'function'
        ? lf.graphModel.getPointByClient.bind(lf.graphModel)
        : null;

  if (getPointByClient) {
    try {
      const result = getPointByClient({ x: clientX, y: clientY });
      const point = result?.canvasOverlayPosition || result;
      if (Number.isFinite(point?.x) && Number.isFinite(point?.y)) {
        return { x: point.x, y: point.y };
      }
    } catch (e) {
      /* fall through to manual transform */
    }
  }

  const rootEl = lf.graphModel?.rootEl || lf.container;
  const transform = lf.graphModel?.transformModel;
  if (!rootEl?.getBoundingClientRect || !transform?.HtmlPointToCanvasPoint) {
    return null;
  }

  const rect = rootEl.getBoundingClientRect();
  const [x, y] = transform.HtmlPointToCanvasPoint([
    clientX - rect.left,
    clientY - rect.top,
  ]);
  if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
  return { x, y };
};

export const getViewportCenterPoint = (lf, hostEl) => {
  if (!hostEl?.getBoundingClientRect) return null;
  const rect = hostEl.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) return null;
  return clientToCanvasPoint(
    lf,
    rect.left + rect.width / 2,
    rect.top + rect.height / 2
  );
};

const nodeTypeOf = node =>
  node?.properties?.workflowNodeType || node?.properties?.type || null;

const listOutboundEdges = (lf, nodeId, outboundIndex = null) => {
  if (outboundIndex) return outboundIndex.get(nodeId) || [];
  const edges = lf?.getGraphData?.()?.edges || lf?.graphModel?.edges || [];
  return edges.filter(edge => edge.sourceNodeId === nodeId);
};

/** One graph read for all stub / placement lookups (avoids O(n) getGraphData). */
export const buildOutboundEdgeIndex = lf => {
  const edges = lf?.getGraphData?.()?.edges || lf?.graphModel?.edges || [];
  const index = new Map();
  edges.forEach(edge => {
    const sourceId = edge?.sourceNodeId;
    if (!sourceId) return;
    if (!index.has(sourceId)) index.set(sourceId, []);
    index.get(sourceId).push(edge);
  });
  return index;
};

const resolveEdgeSourceAnchorId = (edge, lf) => {
  if (edge?.sourceAnchorId) return edge.sourceAnchorId;
  if (!lf || !edge?.id) return null;
  const model = lf.getEdgeModelById?.(edge.id);
  return model?.sourceAnchorId || null;
};

/**
 * All free outbound anchors on a node (branch may return 0–2).
 * Includes preferred Y offset for placing the next step.
 */
export const getAllFreeOutboundAnchors = (lf, nodeId, outboundIndex = null) => {
  if (!lf || !nodeId) return [];
  const node = lf.getNodeModelById?.(nodeId) || lf.getNodeDataById?.(nodeId);
  if (!node) return [];

  const type = nodeTypeOf(node);
  const outbound = listOutboundEdges(lf, nodeId, outboundIndex);
  const used = new Set(
    outbound.map(edge => resolveEdgeSourceAnchorId(edge, lf)).filter(Boolean)
  );

  if (isBranchNodeType(type)) {
    const slots = [
      {
        sourceAnchorId: workflowAnchorOutTrueId(nodeId),
        offsetY: -NODE_INSERT_GAP_Y,
      },
      {
        sourceAnchorId: workflowAnchorOutFalseId(nodeId),
        offsetY: NODE_INSERT_GAP_Y,
      },
    ];
    return slots.filter(slot => !used.has(slot.sourceAnchorId));
  }

  if (outbound.length === 0) {
    return [
      {
        sourceAnchorId: workflowAnchorOutId(nodeId),
        offsetY: 0,
      },
    ];
  }

  return [];
};

/** First free outbound anchor, or null. */
export const getFreeOutboundAnchor = (lf, nodeId, outboundIndex = null) => {
  const all = getAllFreeOutboundAnchors(lf, nodeId, outboundIndex);
  return all[0] || null;
};

export const offsetYForSourceAnchor = sourceAnchorId => {
  const id = String(sourceAnchorId || '');
  if (id.endsWith('_out_true')) return -NODE_INSERT_GAP_Y;
  if (id.endsWith('_out_false')) return NODE_INSERT_GAP_Y;
  return 0;
};

const isOccupied = (lf, x, y, ignoreId = null) => {
  const nodes = lf?.graphModel?.nodes || [];
  return nodes.some(node => {
    if (!node || node.id === ignoreId) return false;
    if (!Number.isFinite(node.x) || !Number.isFinite(node.y)) return false;
    return Math.hypot(node.x - x, node.y - y) < COLLISION_DISTANCE;
  });
};

export const findClearPosition = (lf, x, y, ignoreId = null) => {
  let cx = snapToGrid(x);
  let cy = snapToGrid(y);

  for (let i = 0; i < MAX_COLLISION_NUDGES; i += 1) {
    if (!isOccupied(lf, cx, cy, ignoreId)) return { x: cx, y: cy };
    cy = snapToGrid(cy + WORKFLOW_NODE_HEIGHT + NODE_INSERT_GAP_Y);
  }

  return { x: cx, y: cy };
};

const pickFallbackSourceNode = lf => {
  const nodes = lf?.graphModel?.nodes || [];
  if (!nodes.length) return null;

  const withFreeOut = nodes
    .map(node => ({ node, free: getFreeOutboundAnchor(lf, node.id) }))
    .filter(entry => entry.free);

  if (withFreeOut.length) {
    withFreeOut.sort((a, b) => {
      const dx = (b.node.x || 0) - (a.node.x || 0);
      if (dx !== 0) return dx;
      return (b.node.y || 0) - (a.node.y || 0);
    });
    return withFreeOut[0].node;
  }

  // Prefer rightmost non-trigger as spatial anchor when nothing can connect.
  const ranked = [...nodes].sort((a, b) => {
    const dx = (b.x || 0) - (a.x || 0);
    if (dx !== 0) return dx;
    return (b.y || 0) - (a.y || 0);
  });
  return ranked[0] || null;
};

/**
 * Where to place a node added from the palette (click).
 * Prefer selected node → free-out leaf → viewport center.
 */
export const resolvePaletteInsertPlacement = ({
  lf,
  selectedNodeId,
  newNodeType,
  hostEl,
}) => {
  const viewportCenter = getViewportCenterPoint(lf, hostEl) || { x: 240, y: 180 };

  if (newNodeType === 'trigger') {
    return {
      ...findClearPosition(lf, viewportCenter.x, viewportCenter.y),
      connectFromId: null,
      sourceAnchorId: null,
    };
  }

  let sourceNode = null;
  if (selectedNodeId) {
    sourceNode =
      lf.getNodeModelById?.(selectedNodeId) ||
      lf.getNodeDataById?.(selectedNodeId) ||
      null;
  }
  if (!sourceNode) {
    sourceNode = pickFallbackSourceNode(lf);
  }

  if (!sourceNode || !Number.isFinite(sourceNode.x)) {
    return {
      ...findClearPosition(lf, viewportCenter.x, viewportCenter.y),
      connectFromId: null,
      sourceAnchorId: null,
    };
  }

  const freeOut = getFreeOutboundAnchor(lf, sourceNode.id);
  const offsetY = freeOut?.offsetY || 0;
  const target = findClearPosition(
    lf,
    sourceNode.x + WORKFLOW_NODE_WIDTH + NODE_INSERT_GAP_X,
    sourceNode.y + offsetY
  );

  return {
    ...target,
    connectFromId: freeOut ? sourceNode.id : null,
    sourceAnchorId: freeOut?.sourceAnchorId || null,
  };
};
