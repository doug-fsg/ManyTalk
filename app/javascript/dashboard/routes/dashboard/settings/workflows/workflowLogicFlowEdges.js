import { BezierEdge, BezierEdgeModel } from '@logicflow/core';

export const WORKFLOW_EDGE_TYPE = 'workflow-bezier';

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

class WorkflowBezierView extends BezierEdge {}

export const registerWorkflowEdges = lf => {
  lf.register({
    type: WORKFLOW_EDGE_TYPE,
    view: WorkflowBezierView,
    model: WorkflowBezierModel,
  });
  lf.setDefaultEdgeType(WORKFLOW_EDGE_TYPE);
};
