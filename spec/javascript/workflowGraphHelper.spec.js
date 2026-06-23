import { describe, it, expect } from 'vitest';
import {
  graphToLogicFlowData,
  logicFlowDataToGraph,
  normalizeWorkflowGraph,
  extractInvalidNodeIds,
  validationErrorMessages,
  normalizeValidationErrors,
} from 'dashboard/helper/workflowGraphHelper';
import {
  sourceHandleToAnchorId,
  anchorIdToSourceHandle,
} from 'dashboard/routes/dashboard/settings/workflows/workflowLogicFlowNodes';
import { searchWorkflowIntents } from 'dashboard/routes/dashboard/settings/workflows/constants';

describe('workflowGraphHelper branch anchors', () => {
  it('maps condition sourceHandle to dual anchors', () => {
    const graph = normalizeWorkflowGraph({
      nodes: [
        { id: 'c1', type: 'condition', x: 0, y: 0, data: { conditions: [] } },
        { id: 'a1', type: 'action', x: 200, y: 0, data: {} },
      ],
      edges: [
        { id: 'e1', source: 'c1', target: 'a1', sourceHandle: 'true' },
      ],
    });

    const lfData = graphToLogicFlowData(graph);
    const edge = lfData.edges[0];
    expect(edge.sourceAnchorId).toBe(sourceHandleToAnchorId('c1', 'true'));
    expect(edge.text).toBeTruthy();
  });

  it('infers sourceHandle from anchor when exporting graph', () => {
    const lfData = {
      nodes: [
        {
          id: 'w1',
          type: 'workflow-card',
          x: 0,
          y: 0,
          // workflowNodeType (not nodeType) is the property logicFlowDataToGraph reads
          properties: { workflowNodeType: 'wait_for_reply', duration: 1, unit: 'hours' },
        },
      ],
      edges: [
        {
          id: 'e1',
          sourceNodeId: 'w1',
          targetNodeId: 'a1',
          // All 3 args required: nodeId, sourceHandle, nodeType
          sourceAnchorId: sourceHandleToAnchorId('w1', 'timeout', 'wait_for_reply'),
        },
      ],
    };

    const graph = logicFlowDataToGraph(lfData);
    expect(graph.edges[0].sourceHandle).toBe('timeout');
    expect(
      anchorIdToSourceHandle(
        sourceHandleToAnchorId('w1', 'replied', 'wait_for_reply'),
        'wait_for_reply'
      )
    ).toBe('replied');
  });

  it('resolves wait_for_reply sourceHandle from LogicFlow text object (root cause fix)', () => {
    // LogicFlow stores edge labels as { x, y, value } objects after lf.updateText().
    // This is the real-world data format returned by lf.getGraphData().
    const lfData = {
      nodes: [
        {
          id: 'wr1',
          type: 'workflow-card',
          x: 0,
          y: 0,
          properties: { workflowNodeType: 'wait_for_reply', duration: 24, unit: 'hours' },
        },
        {
          id: 'next',
          type: 'workflow-card',
          x: 200,
          y: 0,
          properties: { workflowNodeType: 'action' },
        },
      ],
      edges: [
        {
          id: 'e_replied',
          sourceNodeId: 'wr1',
          targetNodeId: 'next',
          // No sourceAnchorId (may be absent in some LogicFlow versions)
          text: { x: 100, y: 50, value: 'Respondeu' }, // LogicFlow text object
        },
        {
          id: 'e_timeout',
          sourceNodeId: 'wr1',
          targetNodeId: 'next',
          text: { x: 100, y: 70, value: 'Sem resposta' },
        },
      ],
    };

    const graph = logicFlowDataToGraph(lfData);
    const replied = graph.edges.find(e => e.id === 'e_replied');
    const timeout = graph.edges.find(e => e.id === 'e_timeout');
    expect(replied.sourceHandle).toBe('replied');
    expect(timeout.sourceHandle).toBe('timeout');
  });

  it('normalizeWorkflowGraph coerces text-object sourceHandle to string', () => {
    // Simulate a graph already saved with the text-object bug in sourceHandle
    const graph = normalizeWorkflowGraph({
      nodes: [
        { id: 'wr1', type: 'wait_for_reply', x: 0, y: 0, data: { duration: 1, unit: 'hours' } },
        { id: 'a1', type: 'action', x: 200, y: 0, data: {} },
      ],
      edges: [
        {
          id: 'e1',
          source: 'wr1',
          target: 'a1',
          sourceHandle: { x: 100, y: 50, value: 'Respondeu' }, // text object bug
        },
      ],
    });

    expect(graph.edges[0].sourceHandle).toBe('replied');
  });
});

describe('workflowGraphHelper validation helpers', () => {
  it('extracts node ids from structured errors', () => {
    const ids = extractInvalidNodeIds([
      { message: 'Node wait_reply_1 must have at least one outbound connection', node_id: 'wait_reply_1' },
      { message: 'Graph contains a cycle', node_id: null },
    ]);
    expect(ids).toEqual(['wait_reply_1']);
  });

  it('extracts node ids from plain error strings', () => {
    const ids = extractInvalidNodeIds(['Node action_1 is not reachable from trigger']);
    expect(ids).toEqual(['action_1']);
  });

  it('maps validation errors to messages', () => {
    expect(
      validationErrorMessages([
        { message: 'Invalid action: foo', node_id: 'action_1' },
        'Graph must include nodes array',
      ])
    ).toEqual(['Invalid action: foo', 'Graph must include nodes array']);
  });

  it('normalizes validation errors from strings and objects', () => {
    expect(
      normalizeValidationErrors([
        { message: 'Invalid action: foo', node_id: 'action_1' },
        'Node wait_1 must have at least one outbound connection',
        'Graph must include nodes array',
      ])
    ).toEqual([
      { message: 'Invalid action: foo', node_id: 'action_1' },
      {
        message: 'Node wait_1 must have at least one outbound connection',
        node_id: 'wait_1',
      },
      { message: 'Graph must include nodes array', node_id: null },
    ]);
  });

  it('maps ai_wait_for_intent sourceHandle intent_detected to out_true anchor', () => {
    expect(sourceHandleToAnchorId('n1', 'intent_detected', 'ai_wait_for_intent')).toBe('n1_out_true');
    expect(sourceHandleToAnchorId('n1', 'timeout', 'ai_wait_for_intent')).toBe('n1_out_false');
  });

  it('maps ai_wait_for_intent anchors back to correct sourceHandle', () => {
    expect(anchorIdToSourceHandle('n1_out_true', 'ai_wait_for_intent')).toBe('intent_detected');
    expect(anchorIdToSourceHandle('n1_out_false', 'ai_wait_for_intent')).toBe('timeout');
  });

  it('round-trips ai_wait_for_intent edges through normalizeWorkflowGraph', () => {
    const graph = normalizeWorkflowGraph({
      nodes: [
        { id: 'trigger_1', type: 'trigger', x: 0, y: 0, data: { event_name: 'manual' } },
        { id: 'intent_1', type: 'ai_wait_for_intent', x: 200, y: 0, data: { intent_key: 'quote_request', duration: 30, unit: 'minutes' } },
        { id: 'a_detected', type: 'action', x: 400, y: 0, data: { action_name: 'send_message', action_params: ['ok'] } },
        { id: 'a_timeout', type: 'action', x: 400, y: 120, data: { action_name: 'send_message', action_params: ['timeout'] } },
      ],
      edges: [
        { source: 'trigger_1', target: 'intent_1' },
        { source: 'intent_1', target: 'a_detected', sourceHandle: 'intent_detected' },
        { source: 'intent_1', target: 'a_timeout', sourceHandle: 'timeout' },
      ],
    });

    const detectedEdge = graph.edges.find(e => e.target === 'a_detected');
    const timeoutEdge = graph.edges.find(e => e.target === 'a_timeout');
    expect(detectedEdge.sourceHandle).toBe('intent_detected');
    expect(timeoutEdge.sourceHandle).toBe('timeout');
  });

  it('coerces cross-type handles on ai_wait_for_intent nodes', () => {
    const graph = normalizeWorkflowGraph({
      nodes: [
        { id: 'trigger_1', type: 'trigger', x: 0, y: 0, data: { event_name: 'manual' } },
        { id: 'intent_1', type: 'ai_wait_for_intent', x: 200, y: 0, data: { intent_key: 'quote_request', duration: 30, unit: 'minutes' } },
        { id: 'a1', type: 'action', x: 400, y: 0, data: {} },
      ],
      edges: [
        { source: 'trigger_1', target: 'intent_1' },
        { source: 'intent_1', target: 'a1', sourceHandle: 'true' },
      ],
    });
    const edge = graph.edges.find(e => e.target === 'a1');
    expect(edge.sourceHandle).toBe('intent_detected');
  });

  it('filters intents by search query', () => {
    const results = searchWorkflowIntents('orçamento');
    expect(results.some(i => i.key === 'quote_request')).toBe(true);
    expect(results.some(i => i.key === 'technical_support')).toBe(false);
  });

  it('lays out template graphs without coordinates', () => {
    const graph = normalizeWorkflowGraph({
      nodes: [
        { id: 'trigger_1', type: 'trigger', data: { event_name: 'manual' } },
        { id: 'action_1', type: 'action', data: { action_name: 'send_message', action_params: ['Hi'] } },
        { id: 'wait_1', type: 'wait', data: { duration: 1, unit: 'hours' } },
      ],
      edges: [
        { source: 'trigger_1', target: 'action_1' },
        { source: 'action_1', target: 'wait_1' },
      ],
    });

    expect(graph.nodes[0].x).toBe(120);
    expect(graph.nodes[1].x).toBeGreaterThan(graph.nodes[0].x);
    expect(graph.nodes[2].x).toBeGreaterThan(graph.nodes[1].x);
    expect(graph.nodes[0].y).toBe(graph.nodes[1].y);
  });
});
