import { graphPointToOverlayPoint } from './workflowCanvasViewport';
import {
  clientToCanvasPoint,
  CONNECT_NODE_HIT_PAD,
  CONNECT_SNAP_DISTANCE,
  buildOutboundEdgeIndex,
  getAllFreeOutboundAnchors,
  NODE_STUB_LENGTH,
} from './workflowNodePlacement';
import {
  WORKFLOW_NODE_WIDTH,
  WORKFLOW_NODE_HEIGHT,
  workflowAnchorOutTrueId,
  workflowAnchorOutFalseId,
} from './workflowLogicFlowNodes';

const stubSignature = stubs =>
  stubs
    .map(
      stub =>
        `${stub.nodeId}:${stub.sourceAnchorId}:${Math.round(stub.plusLeft)}:${Math.round(stub.plusTop)}`
    )
    .join('|');

export const computeOutputStubs = lf => {
  if (!lf) return { stubs: [], signature: '' };

  const nodes = lf.graphModel?.nodes || [];
  const outboundIndex = buildOutboundEdgeIndex(lf);
  const stubs = [];

  nodes.forEach(node => {
    if (!node?.id || !Number.isFinite(node.x)) return;
    const freeOuts = getAllFreeOutboundAnchors(lf, node.id, outboundIndex);
    if (!freeOuts.length) return;

    const anchors =
      typeof node.getDefaultAnchor === 'function' ? node.getDefaultAnchor() : [];

    freeOuts.forEach(slot => {
      const anchor = anchors.find(item => item.id === slot.sourceAnchorId);
      if (!anchor) return;

      const from = graphPointToOverlayPoint(lf, { x: anchor.x, y: anchor.y });
      const to = graphPointToOverlayPoint(lf, {
        x: anchor.x + NODE_STUB_LENGTH,
        y: anchor.y,
      });
      if (!from || !to) return;

      stubs.push({
        nodeId: node.id,
        sourceAnchorId: slot.sourceAnchorId,
        x1: from.left,
        y1: from.top,
        x2: to.left,
        y2: to.top,
        plusLeft: to.left,
        plusTop: to.top,
      });
    });
  });

  return { stubs, signature: stubSignature(stubs) };
};

export const buildConnectTargetHints = (lf, sourceNodeId) => {
  if (!lf) return [];

  const hints = [];
  (lf.graphModel?.nodes || []).forEach(node => {
    if (!node?.id || node.id === sourceNodeId) return;
    if (node.properties?.workflowNodeType === 'trigger') return;
    if (!Number.isFinite(node.x)) return;

    const anchors =
      typeof node.getDefaultAnchor === 'function' ? node.getDefaultAnchor() : [];
    const input = anchors.find(item => String(item.id).endsWith('_in'));
    if (!input) return;

    const overlay = graphPointToOverlayPoint(lf, { x: input.x, y: input.y });
    if (!overlay) return;

    hints.push({
      nodeId: node.id,
      graphX: input.x,
      graphY: input.y,
      cx: overlay.left,
      cy: overlay.top,
    });
  });

  return hints;
};

export const findConnectTargetAtClient = (
  lf,
  clientX,
  clientY,
  sourceNodeId,
  hints = []
) => {
  if (!lf) return null;

  const point = clientToCanvasPoint(lf, clientX, clientY);
  if (!point) return null;

  let best = null;
  let bestDist = Infinity;

  hints.forEach(hint => {
    const dist = Math.hypot(point.x - hint.graphX, point.y - hint.graphY);
    if (dist < CONNECT_SNAP_DISTANCE && dist < bestDist) {
      bestDist = dist;
      best = lf.getNodeModelById?.(hint.nodeId) || null;
    }
  });
  if (best) return best;

  const nodes = lf.graphModel?.nodes || [];
  for (let i = nodes.length - 1; i >= 0; i -= 1) {
    const node = nodes[i];
    if (!node || node.id === sourceNodeId || !Number.isFinite(node.x)) continue;
    if (node.properties?.workflowNodeType === 'trigger') continue;

    const halfW = (node.width || WORKFLOW_NODE_WIDTH) / 2 + CONNECT_NODE_HIT_PAD;
    const halfH = (node.height || WORKFLOW_NODE_HEIGHT) / 2 + CONNECT_NODE_HIT_PAD;
    if (
      point.x >= node.x - halfW &&
      point.x <= node.x + halfW &&
      point.y >= node.y - halfH &&
      point.y <= node.y + halfH
    ) {
      return node;
    }
  }

  return null;
};

export const resolveEdgeSourceAnchorId = (lf, edgeData) => {
  if (!lf || !edgeData) return null;

  const edgeModel = lf.getEdgeModelById(edgeData.id);
  const edgeRecord = edgeModel?.getData?.() || edgeData;

  let anchorId =
    edgeRecord.sourceAnchorId ||
    edgeModel?.sourceAnchorId ||
    edgeData.sourceAnchorId;

  if (anchorId) return anchorId;

  const sourceNode = lf.getNodeModelById(edgeData.sourceNodeId);
  if (!sourceNode || typeof sourceNode.getDefaultAnchor !== 'function') {
    return inferBranchAnchorByUsage(lf, edgeData.sourceNodeId, edgeData.id);
  }

  const startPoint = edgeModel?.startPoint || edgeRecord.startPoint;
  if (!startPoint) {
    return inferBranchAnchorByUsage(lf, edgeData.sourceNodeId, edgeData.id);
  }

  const outAnchors = sourceNode
    .getDefaultAnchor()
    .filter(
      anchor =>
        String(anchor.id).endsWith('_out') || String(anchor.id).includes('_out_')
    );

  if (!outAnchors.length) return null;

  let closest = outAnchors[0];
  let minDistance = Infinity;
  outAnchors.forEach(anchor => {
    const distance = Math.hypot(anchor.x - startPoint.x, anchor.y - startPoint.y);
    if (distance < minDistance) {
      minDistance = distance;
      closest = anchor;
    }
  });

  if (edgeModel && closest?.id) {
    edgeModel.sourceAnchorId = closest.id;
  }

  return closest?.id || null;
};

export const inferBranchAnchorByUsage = (lf, sourceNodeId, currentEdgeId) => {
  const trueId = workflowAnchorOutTrueId(sourceNodeId);
  const falseId = workflowAnchorOutFalseId(sourceNodeId);
  const used = new Set();

  (lf.getGraphData()?.edges || []).forEach(edge => {
    if (edge.id === currentEdgeId || edge.sourceNodeId !== sourceNodeId) return;
    const edgeModel = lf.getEdgeModelById(edge.id);
    const anchorId = edge.sourceAnchorId || edgeModel?.sourceAnchorId;
    if (anchorId) used.add(anchorId);
  });

  if (!used.has(trueId)) return trueId;
  if (!used.has(falseId)) return falseId;
  return null;
};

export const hasDuplicateSourceAnchor = (
  lf,
  sourceNodeId,
  sourceAnchorId,
  excludeEdgeId = null
) =>
  (lf?.getGraphData()?.edges || []).some(edge => {
    if (edge.sourceNodeId !== sourceNodeId) return false;
    if (excludeEdgeId && edge.id === excludeEdgeId) return false;
    const model = lf.getEdgeModelById?.(edge.id);
    const anchorId = edge.sourceAnchorId || model?.sourceAnchorId;
    return anchorId === sourceAnchorId;
  });
