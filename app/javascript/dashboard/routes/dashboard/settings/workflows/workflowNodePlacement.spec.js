import { describe, it, expect } from 'vitest';
import {
  snapToGrid,
  clientToCanvasPoint,
  findClearPosition,
  getAllFreeOutboundAnchors,
  getFreeOutboundAnchor,
  resolvePaletteInsertPlacement,
} from 'dashboard/routes/dashboard/settings/workflows/workflowNodePlacement';

const buildLf = ({ nodes = [], edges = [], canvasPoint = { x: 400, y: 300 } } = {}) => {
  const nodeMap = Object.fromEntries(nodes.map(n => [n.id, n]));
  return {
    graphModel: { nodes },
    getGraphData: () => ({ edges, nodes }),
    getNodeModelById: id => nodeMap[id] || null,
    getNodeDataById: id => nodeMap[id] || null,
    getEdgeModelById: () => null,
    getPointByClient: () => ({
      canvasOverlayPosition: canvasPoint,
      domOverlayPosition: { x: 0, y: 0 },
    }),
  };
};

describe('workflowNodePlacement', () => {
  it('snaps coordinates to the canvas grid', () => {
    expect(snapToGrid(214)).toBe(210);
    expect(snapToGrid(215)).toBe(220);
  });

  it('reads canvasOverlayPosition from LogicFlow getPointByClient', () => {
    const lf = buildLf({ canvasPoint: { x: 120, y: 80 } });
    expect(clientToCanvasPoint(lf, 500, 400)).toEqual({ x: 120, y: 80 });
  });

  it('nudges clear of colliding nodes', () => {
    const lf = buildLf({
      nodes: [{ id: 'a', x: 200, y: 200, properties: { workflowNodeType: 'action' } }],
    });
    const clear = findClearPosition(lf, 200, 200);
    expect(clear.x).toBe(200);
    expect(clear.y).toBeGreaterThan(200);
  });

  it('returns free branch true arm before false', () => {
    const lf = buildLf({
      nodes: [
        {
          id: 'cond',
          x: 0,
          y: 0,
          properties: { workflowNodeType: 'condition' },
        },
      ],
      edges: [],
    });
    const free = getFreeOutboundAnchor(lf, 'cond');
    expect(free.sourceAnchorId).toBe('cond_out_true');
    expect(getAllFreeOutboundAnchors(lf, 'cond')).toHaveLength(2);
  });

  it('places next to selected node and prepares auto-connect', () => {
    const selected = {
      id: 'sel',
      x: 100,
      y: 100,
      properties: { workflowNodeType: 'action' },
    };
    const lf = buildLf({ nodes: [selected], edges: [] });
    const hostEl = {
      getBoundingClientRect: () => ({ left: 0, top: 0, width: 800, height: 600 }),
    };

    const placement = resolvePaletteInsertPlacement({
      lf,
      selectedNodeId: 'sel',
      newNodeType: 'action',
      hostEl,
    });

    expect(placement.connectFromId).toBe('sel');
    expect(placement.sourceAnchorId).toBe('sel_out');
    expect(placement.x).toBeGreaterThan(selected.x);
  });

  it('does not auto-connect when adding a trigger', () => {
    const lf = buildLf({
      nodes: [
        {
          id: 'sel',
          x: 100,
          y: 100,
          properties: { workflowNodeType: 'action' },
        },
      ],
    });
    const placement = resolvePaletteInsertPlacement({
      lf,
      selectedNodeId: 'sel',
      newNodeType: 'trigger',
      hostEl: {
        getBoundingClientRect: () => ({ left: 0, top: 0, width: 800, height: 600 }),
      },
    });
    expect(placement.connectFromId).toBeNull();
  });
});
