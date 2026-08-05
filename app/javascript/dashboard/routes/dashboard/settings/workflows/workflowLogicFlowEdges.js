import { BezierEdge, BezierEdgeModel, h } from '@logicflow/core';

export const WORKFLOW_EDGE_TYPE = 'workflow-bezier';
const EDGE_HIT_WIDTH = 28;

class WorkflowBezierModel extends BezierEdgeModel {
  initEdgeData(data) {
    super.initEdgeData(data);
    this.draggable = false;
  }

  getEdgeStyle() {
    const style = super.getEdgeStyle();
    style.strokeWidth = 2;
    return style;
  }
}

class WorkflowBezierView extends BezierEdge {
  getAppendWidth() {
    const { path } = this.props.model;
    return h('path', {
      d: path,
      strokeWidth: EDGE_HIT_WIDTH,
      stroke: 'transparent',
      fill: 'none',
    });
  }
}

export const registerWorkflowEdges = lf => {
  lf.register({
    type: WORKFLOW_EDGE_TYPE,
    view: WorkflowBezierView,
    model: WorkflowBezierModel,
  });
  lf.setDefaultEdgeType(WORKFLOW_EDGE_TYPE);
};

export const addWorkflowEdge = (
  lf,
  { sourceNodeId, targetNodeId, sourceAnchorId, targetAnchorId }
) =>
  lf?.addEdge({
    type: WORKFLOW_EDGE_TYPE,
    sourceNodeId,
    targetNodeId,
    sourceAnchorId,
    targetAnchorId,
  });
