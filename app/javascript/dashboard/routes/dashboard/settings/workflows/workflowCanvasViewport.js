export const WORKFLOW_CANVAS_ZOOM = {
  DEFAULT: 1,
  MIN: 0.25,
  MAX: 2,
  STEP: 0.1,
  /** Never zoom in beyond 100% when auto-fitting (avoids giant single nodes). */
  MAX_AUTO_FIT: 1,
  FIT_PADDING: 80,
  /** Graphs with this many nodes or fewer open at default zoom instead of fit. */
  SPARSE_NODE_THRESHOLD: 2,
};

export const configureWorkflowCanvasZoom = lf => {
  if (!lf) return;
  if (typeof lf.setZoomMiniSize === 'function') {
    lf.setZoomMiniSize(WORKFLOW_CANVAS_ZOOM.MIN);
  }
  if (typeof lf.setZoomMaxSize === 'function') {
    lf.setZoomMaxSize(WORKFLOW_CANVAS_ZOOM.MAX);
  }
};

export const getCanvasZoomPercent = lf => {
  const scale = lf?.graphModel?.transformModel?.SCALE_X ?? 1;
  return Math.round(scale * 100);
};

const clampZoom = scale =>
  Math.min(
    WORKFLOW_CANVAS_ZOOM.MAX,
    Math.max(WORKFLOW_CANVAS_ZOOM.MIN, scale)
  );

export const getGraphCenterCoordinate = lf => {
  const nodes = lf?.graphModel?.nodes || [];
  if (!nodes.length) return null;

  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;

  nodes.forEach(node => {
    if (!Number.isFinite(node.x) || !Number.isFinite(node.y)) return;
    const width = node.width || 128;
    const height = node.height || 84;
    minX = Math.min(minX, node.x - width / 2);
    maxX = Math.max(maxX, node.x + width / 2);
    minY = Math.min(minY, node.y - height / 2);
    maxY = Math.max(maxY, node.y + height / 2);
  });

  if (!Number.isFinite(minX)) return null;

  return {
    x: (minX + maxX) / 2,
    y: (minY + maxY) / 2,
  };
};

const focusOnCoordinate = (lf, coordinate) => {
  if (
    !lf ||
    typeof lf.focusOn !== 'function' ||
    !coordinate ||
    !Number.isFinite(coordinate.x) ||
    !Number.isFinite(coordinate.y)
  ) {
    return;
  }

  lf.focusOn({ coordinate: { x: coordinate.x, y: coordinate.y } });
};

const focusGraphCenter = lf => {
  if (!lf || typeof lf.focusOn !== 'function') return;

  const nodes = lf.graphModel?.nodes || [];
  const trigger = nodes.find(node => node.properties?.workflowNodeType === 'trigger');

  if (trigger?.id) {
    lf.focusOn({ id: trigger.id });
    return;
  }

  focusOnCoordinate(lf, getGraphCenterCoordinate(lf));
};

export const applyInitialCanvasViewport = lf => {
  if (!lf) return getCanvasZoomPercent(lf);

  configureWorkflowCanvasZoom(lf);

  const nodeCount = lf.graphModel?.nodes?.length || 0;

  if (nodeCount <= WORKFLOW_CANVAS_ZOOM.SPARSE_NODE_THRESHOLD) {
    if (typeof lf.resetZoom === 'function') lf.resetZoom();
    if (typeof lf.zoom === 'function') lf.zoom(WORKFLOW_CANVAS_ZOOM.DEFAULT);
    focusGraphCenter(lf);
    return getCanvasZoomPercent(lf);
  }

  return fitCanvasView(lf);
};

export const fitCanvasView = lf => {
  if (!lf || typeof lf.fitView !== 'function') return getCanvasZoomPercent(lf);

  const { FIT_PADDING, MAX_AUTO_FIT } = WORKFLOW_CANVAS_ZOOM;
  lf.fitView(FIT_PADDING, FIT_PADDING);

  const scale = lf.graphModel?.transformModel?.SCALE_X ?? 1;
  if (scale > MAX_AUTO_FIT && typeof lf.zoom === 'function') {
    lf.zoom(MAX_AUTO_FIT);
    focusGraphCenter(lf);
  }

  return getCanvasZoomPercent(lf);
};

export const zoomCanvasByStep = (lf, direction) => {
  if (!lf || typeof lf.zoom !== 'function') return getCanvasZoomPercent(lf);

  const current = lf.graphModel?.transformModel?.SCALE_X ?? 1;
  const next = clampZoom(current + direction * WORKFLOW_CANVAS_ZOOM.STEP);
  lf.zoom(next);
  return getCanvasZoomPercent(lf);
};

export const resetCanvasZoom = lf => {
  if (!lf) return getCanvasZoomPercent(lf);

  if (typeof lf.resetZoom === 'function') lf.resetZoom();
  if (typeof lf.zoom === 'function') lf.zoom(WORKFLOW_CANVAS_ZOOM.DEFAULT);
  focusGraphCenter(lf);
  return getCanvasZoomPercent(lf);
};

/** Midpoint on a bezier edge path (graph coordinates). */
export const getEdgeGraphMidpoint = edgeModel => {
  if (!edgeModel) return null;

  const points = edgeModel.pointsList;
  if (Array.isArray(points) && points.length > 0) {
    const mid = points[Math.floor(points.length / 2)];
    if (mid && Number.isFinite(mid.x) && Number.isFinite(mid.y)) {
      return { x: mid.x, y: mid.y };
    }
  }

  if (!edgeModel.startPoint || !edgeModel.endPoint) return null;

  return {
    x: (edgeModel.startPoint.x + edgeModel.endPoint.x) / 2,
    y: (edgeModel.startPoint.y + edgeModel.endPoint.y) / 2,
  };
};

/** Graph/canvas coordinates → HTML overlay pixels (respects zoom + pan). */
export const graphPointToOverlayPoint = (lf, point) => {
  if (!lf?.graphModel?.transformModel || !point) return null;

  const [left, top] = lf.graphModel.transformModel.CanvasPointToHtmlPoint([
    point.x,
    point.y,
  ]);

  return { left, top };
};
