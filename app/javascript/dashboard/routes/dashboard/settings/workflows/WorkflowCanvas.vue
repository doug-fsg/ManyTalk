<script>
import LogicFlow from '@logicflow/core';
import '@logicflow/core/dist/style/index.css';
import debounce from 'lodash/debounce';
import { useAlert } from 'dashboard/composables';
import './workflow-canvas.scss';
import {
  exportGraphFromLogicFlow,
  graphToLogicFlowData,
  nextNodeId,
  workflowGraphSnapshot,
} from 'dashboard/helper/workflowGraphHelper';
import { WORKFLOW_CANVAS_GRID_SIZE, WORKFLOW_NODE_PALETTE, AI_OUTREACH_DEFAULTS, AI_ANALYSIS_DEFAULTS, AI_WAIT_FOR_INTENT_DEFAULTS } from './constants';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { mapGetters } from 'vuex';
import WorkflowAiUpsellModal from './WorkflowAiUpsellModal.vue';
import {
  registerWorkflowNodes,
  getLogicFlowTheme,
  WORKFLOW_LF_NODE_TYPE,
  WORKFLOW_NODE_WIDTH,
  WORKFLOW_NODE_HEIGHT,
  isBranchNodeType,
  anchorIdToSourceHandle,
  sourceHandleLabel,
  workflowAnchorInId,
  workflowAnchorOutId,
  workflowAnchorOutTrueId,
  workflowAnchorOutFalseId,
  isWorkflowCanvasDark,
  setWorkflowCanvasDarkMode,
  getWorkflowNodeVisual,
} from './workflowLogicFlowNodes';
import {
  registerWorkflowEdges,
  WORKFLOW_EDGE_TYPE,
} from './workflowLogicFlowEdges';
import {
  applyInitialCanvasViewport,
  configureWorkflowCanvasZoom,
  fitCanvasView,
  getCanvasZoomPercent,
  getEdgeGraphMidpoint,
  graphPointToOverlayPoint,
  resetCanvasZoom,
  zoomCanvasByStep,
} from './workflowCanvasViewport';
import {
  clientToCanvasPoint,
  CONNECT_DRAG_THRESHOLD,
  CONNECT_NODE_HIT_PAD,
  CONNECT_SNAP_DISTANCE,
  findClearPosition,
  getAllFreeOutboundAnchors,
  getFreeOutboundAnchor,
  NODE_INSERT_GAP_X,
  NODE_STUB_LENGTH,
  offsetYForSourceAnchor,
  resolvePaletteInsertPlacement,
} from './workflowNodePlacement';

export default {
  name: 'WorkflowCanvas',
  components: {
    WorkflowAiUpsellModal,
  },
  props: {
    graph: { type: Object, required: true },
    graphRevision: { type: Number, default: 0 },
    readOnly: { type: Boolean, default: false },
    invalidNodeIds: { type: Array, default: () => [] },
  },
  data() {
    return {
      lf: null,
      selectedNode: null,
      paletteCollapsed: false,
      isDarkMode: isWorkflowCanvasDark(),
      suspendGraphSync: false,
      lastSyncedGraphSnapshot: null,
      isDropActive: false,
      dragPaletteType: null,
      edgeToolbar: null,
      edgeToolbarHovering: false,
      edgeToolbarHideTimer: null,
      edgeInsertPicker: null,
      /** n8n-style dangling stubs: [{ nodeId, sourceAnchorId, x1,y1,x2,y2, plusLeft, plusTop }] */
      outputStubs: [],
      connectPreview: null,
      stubPointer: null,
      /** Input-port hints while dragging a connection: [{ nodeId, cx, cy }] */
      connectTargetHints: [],
      connectHoverNodeId: null,
      /** Node hover trash overlay: { nodeId, left, top } or null */
      hoveredNode: null,
      nodeHoverTimer: null,
      zoomPercent: 100,
      showAiUpsellModal: false,
    };
  },
  created() {
    this.debouncedEmitGraphChange = debounce(this.emitGraphChangeNow, 300);
    this.debouncedResizeCanvas = debounce(this.resizeCanvasNow, 150);
    this.onStubPointerMove = this.onStubPointerMove.bind(this);
    this.onStubPointerUp = this.onStubPointerUp.bind(this);
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    isAiFeatureEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.IA
      );
    },
    paletteGroups() {
      const groups = {};
      WORKFLOW_NODE_PALETTE.forEach(item => {
        if (this.isAiNodeType(item.type) && !this.isAiFeatureEnabled) return;
        if (!groups[item.group]) groups[item.group] = [];
        groups[item.group].push(item);
      });
      return groups;
    },
    /** Mid-edge insert: never add a second trigger. */
    insertablePaletteItems() {
      return WORKFLOW_NODE_PALETTE.filter(item => {
        if (item.type === 'trigger') return false;
        if (this.isAiNodeType(item.type) && !this.isAiFeatureEnabled) return false;
        return true;
      });
    },
    canvasHostClass() {
      const classes = [this.isDarkMode ? 'workflow-canvas--dark' : 'workflow-canvas--light'];
      if (this.isDropActive) classes.push('workflow-canvas-host--drop-active');
      if (this.connectPreview) classes.push('workflow-canvas-host--connecting');
      return classes.join(' ');
    },
    showOutputStubs() {
      return !this.readOnly && this.outputStubs.length > 0;
    },
  },
  watch: {
    graphRevision() {
      this.renderGraph();
    },
    isDarkMode(val) {
      setWorkflowCanvasDarkMode(val);
      this.applyTheme();
      this.rerenderNodesForTheme();
    },
    readOnly(val) {
      this.applyReadOnlyMode(val);
    },
    invalidNodeIds: {
      handler() {
        this.applyInvalidHighlights();
      },
      deep: true,
    },
  },
  mounted() {
    setWorkflowCanvasDarkMode(this.isDarkMode);
    this.themeObserver = new MutationObserver(() => {
      const dark = isWorkflowCanvasDark();
      if (dark !== this.isDarkMode) {
        this.isDarkMode = dark;
      }
    });
    this.themeObserver.observe(document.body, {
      attributes: true,
      attributeFilter: ['class'],
    });
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class', 'style'],
    });
    this.initLogicFlow();
    this.applyReadOnlyMode(this.readOnly);
    this.renderGraph();
    this.resizeCanvas();
    window.addEventListener('resize', this.debouncedResizeCanvas);
  },
  beforeDestroy() {
    if (this.debouncedEmitGraphChange && this.debouncedEmitGraphChange.cancel) {
      this.debouncedEmitGraphChange.cancel();
    }
    if (this.debouncedResizeCanvas && this.debouncedResizeCanvas.cancel) {
      this.debouncedResizeCanvas.cancel();
    }
    if (this.themeObserver) this.themeObserver.disconnect();
    window.removeEventListener('resize', this.debouncedResizeCanvas);
    if (this.edgeToolbarHideTimer) clearTimeout(this.edgeToolbarHideTimer);
    this.teardownStubPointerListeners();
    if (this.lf) {
      if (typeof this.lf.clearData === 'function') {
        this.lf.clearData();
      }
      if (this.$refs.canvas) {
        this.$refs.canvas.innerHTML = '';
      }
      this.lf = null;
    }
  },
  methods: {
    initLogicFlow() {
      // Wheel listener is non-passive in @logicflow/core (DevTools violation); upstream limitation.
      this.lf = new LogicFlow({
        container: this.$refs.canvas,
        grid: { visible: true, type: 'dot', size: WORKFLOW_CANVAS_GRID_SIZE },
        keyboard: { enabled: !this.readOnly },
        isSilentMode: this.readOnly,
        edgeType: WORKFLOW_EDGE_TYPE,
        adjustNodePosition: true,
        textEdit: false,
      });
      registerWorkflowNodes(this.lf);
      registerWorkflowEdges(this.lf);
      configureWorkflowCanvasZoom(this.lf);
      this.applyTheme();

      this.lf.on('node:click', ({ data }) => {
        this.hideEdgeToolbar();
        this.selectedNode = data;
        this.$emit('node-selected', data);
      });
      this.lf.on('blank:click', () => {
        this.hideEdgeToolbar();
        this.selectedNode = null;
        this.$emit('node-selected', null);
      });
      this.lf.on('history:change', () => { this.debouncedEmitGraphChange(); });

      this.lf.on('edge:add', ({ data }) => {
        this.onEdgeAdded(data);
      });

      this.lf.on('edge:click', ({ data }) => {
        this.onEdgeSelected(data);
      });
      this.lf.on('edge:mouseenter', ({ data }) => {
        this.onEdgeMouseEnter(data);
      });
      this.lf.on('edge:mouseleave', () => {
        this.scheduleHideEdgeToolbar();
      });
      this.lf.on('graph:transform', () => {
        this.syncZoomLevel();
        this.refreshOutputStubs();
        this.refreshNodeHoverPosition();
        if (this.edgeToolbar && this.edgeToolbar.edgeId) {
          this.updateEdgeToolbarPosition(this.edgeToolbar.edgeId);
        }
        if (this.edgeInsertPicker?.mode === 'edge' && this.edgeInsertPicker.edgeId) {
          this.updateEdgeInsertPickerPosition(this.edgeInsertPicker.edgeId);
        }
        if (this.edgeInsertPicker?.mode === 'node') {
          this.updateNodeInsertPickerPosition();
        }
      });

      this.lf.on('node:drag', () => {
        this.refreshOutputStubs();
        this.clearNodeHover();
        if (this.edgeToolbar && this.edgeToolbar.edgeId) {
          this.updateEdgeToolbarPosition(this.edgeToolbar.edgeId);
        }
      });

      this.lf.on('node:mouseenter', ({ data }) => {
        if (!this.readOnly) this.onNodeMouseEnter(data);
      });
      this.lf.on('node:mouseleave', () => {
        this.scheduleHideNodeHover();
      });
    },

    onEdgeSelected(edgeData) {
      if (this.readOnly || !edgeData) return;
      if (this.edgeToolbarHideTimer) {
        clearTimeout(this.edgeToolbarHideTimer);
        this.edgeToolbarHideTimer = null;
      }
      this.edgeInsertPicker = null;
      this.edgeToolbar = { edgeId: edgeData.id };
      this.updateEdgeToolbarPosition(edgeData.id);
    },

    onEdgeMouseEnter(edgeData) {
      if (this.readOnly || !edgeData || this.edgeInsertPicker || this.connectPreview) {
        return;
      }
      if (this.edgeToolbarHideTimer) {
        clearTimeout(this.edgeToolbarHideTimer);
        this.edgeToolbarHideTimer = null;
      }
      this.edgeToolbar = { edgeId: edgeData.id };
      this.updateEdgeToolbarPosition(edgeData.id);
    },

    scheduleHideEdgeToolbar() {
      if (this.edgeToolbarHovering || this.edgeInsertPicker) return;
      if (this.edgeToolbarHideTimer) clearTimeout(this.edgeToolbarHideTimer);
      this.edgeToolbarHideTimer = setTimeout(() => {
        if (!this.edgeToolbarHovering && !this.edgeInsertPicker) {
          this.edgeToolbar = null;
        }
      }, 320);
    },

    hideEdgeToolbar() {
      this.edgeToolbarHovering = false;
      this.edgeToolbar = null;
      this.edgeInsertPicker = null;
      if (this.edgeToolbarHideTimer) {
        clearTimeout(this.edgeToolbarHideTimer);
        this.edgeToolbarHideTimer = null;
      }
    },

    updateEdgeToolbarPosition(edgeId) {
      if (!this.lf || !this.$refs.canvasWrapper) return;
      const edgeModel = this.lf.getEdgeModelById(edgeId);
      const graphPoint = getEdgeGraphMidpoint(edgeModel);
      const overlay = graphPointToOverlayPoint(this.lf, graphPoint);
      if (!overlay) return;

      this.edgeToolbar = {
        edgeId,
        left: overlay.left,
        top: overlay.top,
      };
    },

    deleteHoveredEdge() {
      if (!this.lf || !this.edgeToolbar || this.readOnly) return;
      this.lf.deleteEdge(this.edgeToolbar.edgeId);
      this.hideEdgeToolbar();
      this.emitGraphChangeNow();
    },

    focusInsertPicker() {
      this.$nextTick(() => {
        const picker = this.$el?.querySelector?.('.workflow-edge-insert-picker');
        if (picker && typeof picker.focus === 'function') picker.focus();
      });
    },

    openEdgeInsertPicker() {
      if (!this.lf || !this.edgeToolbar || this.readOnly) return;
      const edgeId = this.edgeToolbar.edgeId;
      this.edgeInsertPicker = { mode: 'edge', edgeId };
      this.updateEdgeInsertPickerPosition(edgeId);
      this.focusInsertPicker();
    },

    openNodeNextStepPicker(nodeId, sourceAnchorId) {
      if (!this.lf || !nodeId || this.readOnly) return;
      this.hideEdgeToolbar();
      this.edgeInsertPicker = {
        mode: 'node',
        nodeId,
        sourceAnchorId,
      };
      this.updateNodeInsertPickerPosition();
      this.focusInsertPicker();
    },

    closeEdgeInsertPicker() {
      const picker = this.edgeInsertPicker;
      this.edgeInsertPicker = null;
      if (!picker || this.readOnly) return;

      if (picker.mode === 'edge' && picker.edgeId) {
        this.edgeToolbar = { edgeId: picker.edgeId };
        this.updateEdgeToolbarPosition(picker.edgeId);
      }
    },

    onEdgeInsertPickerKeydown(event) {
      if (event.key === 'Escape') {
        event.preventDefault();
        this.closeEdgeInsertPicker();
      }
    },

    updateEdgeInsertPickerPosition(edgeId) {
      if (!this.lf || !this.$refs.canvasWrapper) return;
      const edgeModel = this.lf.getEdgeModelById(edgeId);
      const graphPoint = getEdgeGraphMidpoint(edgeModel);
      const overlay = graphPointToOverlayPoint(this.lf, graphPoint);
      if (!overlay) return;

      this.edgeInsertPicker = {
        ...(this.edgeInsertPicker || {}),
        mode: 'edge',
        edgeId,
        left: overlay.left,
        top: overlay.top,
      };
    },

    updateNodeInsertPickerPosition() {
      if (!this.lf || !this.edgeInsertPicker || this.edgeInsertPicker.mode !== 'node') {
        return;
      }
      const { nodeId, sourceAnchorId } = this.edgeInsertPicker;
      const stub = this.outputStubs.find(
        item => item.nodeId === nodeId && item.sourceAnchorId === sourceAnchorId
      );
      if (stub) {
        this.edgeInsertPicker = {
          ...this.edgeInsertPicker,
          left: stub.plusLeft + 14,
          top: stub.plusTop,
        };
        return;
      }

      const model = this.lf.getNodeModelById(nodeId);
      if (!model) return;
      const anchors =
        typeof model.getDefaultAnchor === 'function' ? model.getDefaultAnchor() : [];
      const anchor = anchors.find(item => item.id === sourceAnchorId);
      const graphPoint = anchor
        ? { x: anchor.x + NODE_STUB_LENGTH, y: anchor.y }
        : { x: model.x + model.width / 2 + NODE_STUB_LENGTH, y: model.y };
      const overlay = graphPointToOverlayPoint(this.lf, graphPoint);
      if (!overlay) return;

      this.edgeInsertPicker = {
        ...this.edgeInsertPicker,
        left: overlay.left + 14,
        top: overlay.top,
      };
    },

    selectEdgeInsertType(paletteItem) {
      if (!paletteItem || this.readOnly) return;
      if (this.isAiNodeType(paletteItem.type) && !this.isAiFeatureEnabled) {
        this.showAiUpsellModal = true;
        return;
      }

      if (this.edgeInsertPicker?.mode === 'node') {
        this.addNextStepFromNode(
          this.edgeInsertPicker.nodeId,
          this.edgeInsertPicker.sourceAnchorId,
          paletteItem
        );
        return;
      }

      const edgeId = this.edgeInsertPicker?.edgeId || this.edgeToolbar?.edgeId;
      if (!edgeId) return;
      this.insertNodeOnEdge(edgeId, paletteItem);
    },

    addNextStepFromNode(nodeId, sourceAnchorId, paletteItem) {
      if (!this.lf || this.readOnly || !nodeId || !paletteItem) return;
      if (paletteItem.type === 'trigger') return;

      const source = this.lf.getNodeModelById(nodeId);
      if (!source) return;

      const offsetY = offsetYForSourceAnchor(sourceAnchorId);
      const target = findClearPosition(
        this.lf,
        source.x + WORKFLOW_NODE_WIDTH + NODE_INSERT_GAP_X,
        source.y + offsetY
      );

      this.edgeInsertPicker = null;
      this.addNodeAt(paletteItem, target.x, target.y, {
        connectFromId: nodeId,
        sourceAnchorId: sourceAnchorId || workflowAnchorOutId(nodeId),
        focus: true,
      });
    },

    refreshOutputStubs() {
      if (!this.lf || this.readOnly) {
        this.outputStubs = [];
        return;
      }

      const nodes = this.lf.graphModel?.nodes || [];
      const stubs = [];

      nodes.forEach(node => {
        if (!node?.id || !Number.isFinite(node.x)) return;
        const freeOuts = getAllFreeOutboundAnchors(this.lf, node.id);
        if (!freeOuts.length) return;

        const anchors =
          typeof node.getDefaultAnchor === 'function' ? node.getDefaultAnchor() : [];

        freeOuts.forEach(slot => {
          const anchor = anchors.find(item => item.id === slot.sourceAnchorId);
          if (!anchor) return;

          const from = graphPointToOverlayPoint(this.lf, {
            x: anchor.x,
            y: anchor.y,
          });
          const to = graphPointToOverlayPoint(this.lf, {
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

      this.outputStubs = stubs;
    },

    teardownStubPointerListeners() {
      window.removeEventListener('pointermove', this.onStubPointerMove);
      window.removeEventListener('pointerup', this.onStubPointerUp);
      window.removeEventListener('pointercancel', this.onStubPointerUp);
      const captureEl = this.stubPointer?.captureEl;
      const pointerId = this.stubPointer?.pointerId;
      if (captureEl && pointerId != null) {
        try {
          captureEl.releasePointerCapture(pointerId);
        } catch (e) {
          /* ignore */
        }
      }
      this.stubPointer = null;
      this.connectPreview = null;
      this.connectTargetHints = [];
      this.connectHoverNodeId = null;
    },

    buildConnectTargetHints(sourceNodeId) {
      if (!this.lf) return [];
      const nodes = this.lf.graphModel?.nodes || [];
      const hints = [];

      nodes.forEach(node => {
        if (!node?.id || node.id === sourceNodeId) return;
        if (node.properties?.workflowNodeType === 'trigger') return;
        if (!Number.isFinite(node.x)) return;

        const anchors =
          typeof node.getDefaultAnchor === 'function' ? node.getDefaultAnchor() : [];
        const input = anchors.find(item => String(item.id).endsWith('_in'));
        if (!input) return;

        const overlay = graphPointToOverlayPoint(this.lf, {
          x: input.x,
          y: input.y,
        });
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
    },

    onNodeMouseEnter(data) {
      if (!data?.id || !this.lf) return;
      if (this.nodeHoverTimer) {
        clearTimeout(this.nodeHoverTimer);
        this.nodeHoverTimer = null;
      }
      const nodeModel =
        this.lf.getNodeModelById?.(data.id) || data;
      if (!nodeModel || !Number.isFinite(nodeModel.x)) return;

      const overlay = graphPointToOverlayPoint(this.lf, {
        x: nodeModel.x,
        y: nodeModel.y - (nodeModel.height || 84) / 2,
      });
      if (!overlay) return;

      this.hoveredNode = {
        nodeId: data.id,
        left: overlay.left,
        top: overlay.top,
      };
    },

    scheduleHideNodeHover() {
      if (this.nodeHoverTimer) clearTimeout(this.nodeHoverTimer);
      this.nodeHoverTimer = setTimeout(() => {
        this.hoveredNode = null;
        this.nodeHoverTimer = null;
      }, 280);
    },

    keepNodeHover() {
      if (this.nodeHoverTimer) {
        clearTimeout(this.nodeHoverTimer);
        this.nodeHoverTimer = null;
      }
    },

    clearNodeHover() {
      if (this.nodeHoverTimer) clearTimeout(this.nodeHoverTimer);
      this.nodeHoverTimer = null;
      this.hoveredNode = null;
    },

    refreshNodeHoverPosition() {
      if (!this.hoveredNode || !this.lf) return;
      const nodeModel = this.lf.getNodeModelById?.(this.hoveredNode.nodeId);
      if (!nodeModel || !Number.isFinite(nodeModel.x)) return;
      const overlay = graphPointToOverlayPoint(this.lf, {
        x: nodeModel.x,
        y: nodeModel.y - (nodeModel.height || 84) / 2,
      });
      if (!overlay) return;
      this.hoveredNode = { ...this.hoveredNode, left: overlay.left, top: overlay.top };
    },

    deleteHoveredNode() {
      if (!this.lf || !this.hoveredNode || this.readOnly) return;
      const { nodeId } = this.hoveredNode;
      this.clearNodeHover();
      this.lf.deleteNode(nodeId);
      if (this.selectedNode?.id === nodeId) {
        this.selectedNode = null;
        this.$emit('node-selected', null);
      }
      this.refreshOutputStubs();
      this.emitGraphChangeNow();
    },

    onStubPlusPointerDown(stub, event) {
      if (this.readOnly || event.button !== 0) return;
      event.preventDefault();
      event.stopPropagation();
      this.hideEdgeToolbar();
      this.clearNodeHover();

      const target = event.currentTarget;
      if (target && typeof target.setPointerCapture === 'function') {
        try {
          target.setPointerCapture(event.pointerId);
        } catch (e) {
          /* ignore */
        }
      }

      this.stubPointer = {
        stub,
        startX: event.clientX,
        startY: event.clientY,
        dragging: false,
        pointerId: event.pointerId,
        captureEl: target,
      };
      window.addEventListener('pointermove', this.onStubPointerMove, { passive: false });
      window.addEventListener('pointerup', this.onStubPointerUp);
      window.addEventListener('pointercancel', this.onStubPointerUp);
    },

    onStubPointerMove(event) {
      const state = this.stubPointer;
      if (!state) return;

      const dist = Math.hypot(
        event.clientX - state.startX,
        event.clientY - state.startY
      );
      if (!state.dragging && dist < CONNECT_DRAG_THRESHOLD) return;

      if (!state.dragging) {
        state.dragging = true;
        this.connectTargetHints = this.buildConnectTargetHints(state.stub.nodeId);
      }

      event.preventDefault();

      const wrapper = this.$refs.canvasWrapper?.getBoundingClientRect?.();
      if (!wrapper) return;

      const target = this.findConnectTargetAtClient(event.clientX, event.clientY, state.stub.nodeId);
      this.connectHoverNodeId = target?.id || null;

      let x2 = event.clientX - wrapper.left;
      let y2 = event.clientY - wrapper.top;
      if (target) {
        const hint = this.connectTargetHints.find(item => item.nodeId === target.id);
        if (hint) {
          x2 = hint.cx;
          y2 = hint.cy;
        }
      }

      this.connectPreview = {
        x1: state.stub.x1,
        y1: state.stub.y1,
        x2,
        y2,
      };
    },

    onStubPointerUp(event) {
      const state = this.stubPointer;
      const wasDragging = Boolean(state?.dragging);
      const stub = state?.stub;
      if (!state || !stub || this.readOnly) {
        this.teardownStubPointerListeners();
        return;
      }

      if (!wasDragging) {
        this.teardownStubPointerListeners();
        this.openNodeNextStepPicker(stub.nodeId, stub.sourceAnchorId);
        return;
      }

      // Resolve target before teardown clears connectTargetHints.
      const target = this.findConnectTargetAtClient(
        event.clientX,
        event.clientY,
        stub.nodeId
      );
      this.teardownStubPointerListeners();
      if (!target) return;
      this.connectStubToNode(stub, target);
    },

    findConnectTargetAtClient(clientX, clientY, sourceNodeId) {
      if (!this.lf) return null;
      const point = clientToCanvasPoint(this.lf, clientX, clientY);
      if (!point) return null;

      let best = null;
      let bestDist = Infinity;

      // Prefer snapping to an input port when the cursor is near it.
      this.connectTargetHints.forEach(hint => {
        const dist = Math.hypot(point.x - hint.graphX, point.y - hint.graphY);
        if (dist < CONNECT_SNAP_DISTANCE && dist < bestDist) {
          bestDist = dist;
          best = this.lf.getNodeModelById?.(hint.nodeId) || null;
        }
      });
      if (best) return best;

      const nodes = this.lf.graphModel?.nodes || [];
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
    },

    connectStubToNode(stub, targetNode) {
      if (!this.lf || !stub || !targetNode) return;
      if (stub.nodeId === targetNode.id) return;

      const targetType = targetNode.properties?.workflowNodeType;
      if (targetType === 'trigger') {
        useAlert(this.$t('WORKFLOW.EDITOR.EDGE_CONNECT_TRIGGER_FORBIDDEN'));
        return;
      }

      const existing = (this.lf.getGraphData()?.edges || []).some(edge => {
        if (edge.sourceNodeId !== stub.nodeId) return false;
        const model = this.lf.getEdgeModelById(edge.id);
        const anchorId = edge.sourceAnchorId || model?.sourceAnchorId;
        return anchorId === stub.sourceAnchorId;
      });
      if (existing) {
        useAlert(this.$t('WORKFLOW.EDITOR.EDGE_DUPLICATE_BRANCH'));
        return;
      }

      const edge = this.lf.addEdge({
        type: WORKFLOW_EDGE_TYPE,
        sourceNodeId: stub.nodeId,
        targetNodeId: targetNode.id,
        sourceAnchorId: stub.sourceAnchorId,
        targetAnchorId: workflowAnchorInId(targetNode.id),
      });

      if (!edge) return;

      this.refreshOutputStubs();
      this.emitGraphChangeNow();
    },

    insertNodeOnEdge(edgeId, paletteItem) {
      if (!this.lf || this.readOnly || !paletteItem) return;

      const edgeModel = this.lf.getEdgeModelById(edgeId);
      if (!edgeModel) return;

      const edgeData = edgeModel.getData ? edgeModel.getData() : edgeModel;
      const sourceId = edgeData.sourceNodeId;
      const targetId = edgeData.targetNodeId;
      const sourceAnchorId = this.resolveEdgeSourceAnchorId(edgeData);

      const mx = (edgeModel.startPoint.x + edgeModel.endPoint.x) / 2;
      const my = (edgeModel.startPoint.y + edgeModel.endPoint.y) / 2;

      const newId = nextNodeId();
      const defaultData = this.defaultNodeData(paletteItem.type);

      this.lf.addNode({
        id: newId,
        type: WORKFLOW_LF_NODE_TYPE,
        x: mx,
        y: my,
        text: '',
        properties: { workflowNodeType: paletteItem.type, ...defaultData },
      });

      this.lf.deleteEdge(edgeId);

      const targetAnchorId = workflowAnchorInId(targetId);
      const newOutAnchorId = workflowAnchorOutId(newId);

      this.lf.addEdge({
        type: WORKFLOW_EDGE_TYPE,
        sourceNodeId: sourceId,
        targetNodeId: newId,
        sourceAnchorId,
        targetAnchorId: workflowAnchorInId(newId),
      });

      this.lf.addEdge({
        type: WORKFLOW_EDGE_TYPE,
        sourceNodeId: newId,
        targetNodeId: targetId,
        sourceAnchorId: newOutAnchorId,
        targetAnchorId: targetAnchorId,
      });

      const newNodeData = this.lf.getNodeDataById(newId);
      this.selectedNode = newNodeData;
      this.$emit('node-selected', newNodeData);
      this.hideEdgeToolbar();
      this.emitGraphChangeNow();
    },

    onEdgeAdded(edgeData) {
      if (!this.lf || !edgeData) return;

      const sourceNode = this.lf.getNodeModelById(edgeData.sourceNodeId);
      const srcType = sourceNode?.properties?.workflowNodeType;
      if (!isBranchNodeType(srcType)) return;

      const sourceAnchorId = this.resolveEdgeSourceAnchorId(edgeData);
      const sourceHandle = anchorIdToSourceHandle(sourceAnchorId, srcType);
      const label = sourceHandleLabel(sourceHandle, srcType);

      const graphData = this.lf.getGraphData();
      const duplicate = (graphData.edges || []).some(edge => {
        if (edge.id === edgeData.id) return false;
        if (edge.sourceNodeId !== edgeData.sourceNodeId) return false;

        const otherAnchorId = this.resolveEdgeSourceAnchorId(edge);
        if (!sourceAnchorId || !otherAnchorId) return false;

        return sourceAnchorId === otherAnchorId;
      });

      if (duplicate) {
        this.lf.deleteEdge(edgeData.id);
        useAlert(this.$t('WORKFLOW.EDITOR.EDGE_DUPLICATE_BRANCH'));
        return;
      }

      if (label && typeof this.lf.updateText === 'function') {
        this.lf.updateText(edgeData.id, label);
      }
    },

    resolveEdgeSourceAnchorId(edgeData) {
      if (!this.lf || !edgeData) return null;

      const edgeModel = this.lf.getEdgeModelById(edgeData.id);
      const edgeRecord = edgeModel?.getData?.() || edgeData;

      let anchorId =
        edgeRecord.sourceAnchorId ||
        edgeModel?.sourceAnchorId ||
        edgeData.sourceAnchorId;

      if (anchorId) return anchorId;

      const sourceNode = this.lf.getNodeModelById(edgeData.sourceNodeId);
      if (!sourceNode || typeof sourceNode.getDefaultAnchor !== 'function') {
        return this.inferBranchAnchorByUsage(edgeData.sourceNodeId, edgeData.id);
      }

      const startPoint = edgeModel?.startPoint || edgeRecord.startPoint;
      if (!startPoint) return this.inferBranchAnchorByUsage(edgeData.sourceNodeId, edgeData.id);

      const outAnchors = sourceNode
        .getDefaultAnchor()
        .filter(anchor => String(anchor.id).endsWith('_out') || String(anchor.id).includes('_out_'));

      if (outAnchors.length === 0) return null;

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
    },

    inferBranchAnchorByUsage(sourceNodeId, currentEdgeId) {
      const trueId = workflowAnchorOutTrueId(sourceNodeId);
      const falseId = workflowAnchorOutFalseId(sourceNodeId);
      const graphData = this.lf.getGraphData();
      const used = new Set();

      (graphData.edges || []).forEach(edge => {
        if (edge.id === currentEdgeId || edge.sourceNodeId !== sourceNodeId) return;
        const edgeModel = this.lf.getEdgeModelById(edge.id);
        const anchorId = edge.sourceAnchorId || edgeModel?.sourceAnchorId;
        if (anchorId) used.add(anchorId);
      });

      if (!used.has(trueId)) return trueId;
      if (!used.has(falseId)) return falseId;
      return null;
    },

    onPaletteDragStart(item, event) {
      if (this.readOnly) return;
      if (this.isAiNodeType(item.type) && !this.isAiFeatureEnabled) {
        event.preventDefault();
        this.showAiUpsellModal = true;
        return;
      }
      this.dragPaletteType = item.type;
      event.dataTransfer.setData('application/workflow-node-type', item.type);
      event.dataTransfer.effectAllowed = 'copy';
    },

    onCanvasDragOver(event) {
      if (this.readOnly || !this.dragPaletteType) return;
      event.preventDefault();
      this.isDropActive = true;
    },

    onCanvasDragLeave() {
      this.isDropActive = false;
    },

    onCanvasDrop(event) {
      if (this.readOnly || !this.lf) return;
      event.preventDefault();
      this.isDropActive = false;

      const type =
        event.dataTransfer.getData('application/workflow-node-type') ||
        this.dragPaletteType;
      this.dragPaletteType = null;
      if (!type) return;

      if (this.isAiNodeType(type) && !this.isAiFeatureEnabled) {
        this.showAiUpsellModal = true;
        return;
      }

      const paletteItem = WORKFLOW_NODE_PALETTE.find(p => p.type === type);
      if (!paletteItem) return;

      // LogicFlow getPointByClient expects raw clientX/Y and returns
      // { canvasOverlayPosition } — relative subtraction was placing nodes off-screen.
      const point = clientToCanvasPoint(this.lf, event.clientX, event.clientY);
      if (!point) return;

      const connectOpts = this.buildConnectOptionsFromSelection(paletteItem.type);
      this.addNodeAt(paletteItem, point.x, point.y, {
        ...connectOpts,
        focus: false,
      });
    },

    applyTheme() {
      if (!this.lf) return;
      this.lf.setTheme(getLogicFlowTheme(this.isDarkMode));
    },

    rerenderNodesForTheme() {
      if (!this.lf) return;
      const data = this.lf.getGraphData();
      this.suspendGraphSync = true;
      this.lf.render(data);
      this.$nextTick(() => {
        this.suspendGraphSync = false;
      });
    },

    applyReadOnlyMode(readOnly) {
      if (!this.lf) return;
      this.lf.updateEditConfig({
        isSilentMode: readOnly,
        hideAnchors: true,
      });
      if (this.lf.keyboard) {
        if (readOnly) this.lf.keyboard.disable();
        else this.lf.keyboard.enable(true);
      }
      if (readOnly) {
        this.hideEdgeToolbar();
        this.outputStubs = [];
        this.teardownStubPointerListeners();
      } else {
        this.refreshOutputStubs();
      }
    },

    resizeCanvas() {
      this.debouncedResizeCanvas();
    },

    resizeCanvasNow() {
      if (!this.lf || !this.$refs.canvasHost) return;
      const { clientWidth, clientHeight } = this.$refs.canvasHost;
      if (clientWidth > 0 && clientHeight > 0) {
        this.lf.resize(clientWidth, clientHeight);
        if (this.edgeToolbar?.edgeId) {
          this.updateEdgeToolbarPosition(this.edgeToolbar.edgeId);
        }
      }
    },

    renderGraph() {
      if (!this.lf) return;
      this.suspendGraphSync = true;
      const data = graphToLogicFlowData(this.graph);
      this.lf.render(data);
      this.$nextTick(() => {
        this.resizeCanvasNow();
        const graph = exportGraphFromLogicFlow(this.lf, this.graph);
        this.lastSyncedGraphSnapshot = workflowGraphSnapshot(graph);
        this.applyInvalidHighlights();
        this.zoomPercent = applyInitialCanvasViewport(this.lf);
        this.refreshOutputStubs();
        this.suspendGraphSync = false;
      });
    },

    syncZoomLevel() {
      if (!this.lf) return;
      this.zoomPercent = getCanvasZoomPercent(this.lf);
    },

    applyInvalidHighlights() {
      if (!this.lf || !this.lf.graphModel || this.readOnly) return;
      const invalidSet = new Set(this.invalidNodeIds || []);
      const nodes = this.lf.graphModel.nodes || [];
      nodes.forEach(nodeModel => {
        const props = { ...(nodeModel.properties || {}) };
        const isInvalid = invalidSet.has(nodeModel.id);
        if (Boolean(props.isInvalid) === isInvalid) return;
        this.lf.setProperties(nodeModel.id, { ...props, isInvalid });
      });
    },

    emitGraphChange() {
      this.debouncedEmitGraphChange();
    },

    emitGraphChangeNow() {
      if (this.suspendGraphSync || !this.lf) return;
      const graph = exportGraphFromLogicFlow(this.lf, this.graph);
      const snapshot = workflowGraphSnapshot(graph);
      if (snapshot === this.lastSyncedGraphSnapshot) {
        this.refreshOutputStubs();
        return;
      }

      this.lastSyncedGraphSnapshot = snapshot;
      this.$emit('update:graph', graph);
      this.refreshOutputStubs();
    },

    getGraphForSave() {
      return exportGraphFromLogicFlow(this.lf, this.graph);
    },

    isAiNodeType(type) {
      return type === 'ai_outreach' || type === 'ai_conversation_analysis';
    },

    buildConnectOptionsFromSelection(newNodeType) {
      if (newNodeType === 'trigger' || !this.selectedNode?.id) {
        return { connectFromId: null, sourceAnchorId: null };
      }
      const freeOut = getFreeOutboundAnchor(this.lf, this.selectedNode.id);
      if (!freeOut) return { connectFromId: null, sourceAnchorId: null };
      return {
        connectFromId: this.selectedNode.id,
        sourceAnchorId: freeOut.sourceAnchorId,
      };
    },

    addNode(paletteItem) {
      if (this.isAiNodeType(paletteItem.type) && !this.isAiFeatureEnabled) {
        this.showAiUpsellModal = true;
        return;
      }
      const placement = resolvePaletteInsertPlacement({
        lf: this.lf,
        selectedNodeId: this.selectedNode?.id || null,
        newNodeType: paletteItem.type,
        hostEl: this.$refs.canvasHost || this.$refs.canvas,
      });
      this.addNodeAt(paletteItem, placement.x, placement.y, {
        connectFromId: placement.connectFromId,
        sourceAnchorId: placement.sourceAnchorId,
        focus: true,
      });
    },

    addNodeAt(paletteItem, x, y, options = {}) {
      if (!this.lf || this.readOnly) return;
      if (!Number.isFinite(x) || !Number.isFinite(y)) return;

      const id = nextNodeId();
      const defaultData = this.defaultNodeData(paletteItem.type);
      const node = {
        id,
        type: WORKFLOW_LF_NODE_TYPE,
        x,
        y,
        text: '',
        properties: { workflowNodeType: paletteItem.type, ...defaultData },
      };
      this.lf.addNode(node);

      const connectFromId = options.connectFromId;
      const sourceAnchorId = options.sourceAnchorId;
      if (connectFromId && paletteItem.type !== 'trigger') {
        this.lf.addEdge({
          type: WORKFLOW_EDGE_TYPE,
          sourceNodeId: connectFromId,
          targetNodeId: id,
          sourceAnchorId: sourceAnchorId || workflowAnchorOutId(connectFromId),
          targetAnchorId: workflowAnchorInId(id),
        });
      }

      const newNodeData = this.lf.getNodeDataById
        ? this.lf.getNodeDataById(id)
        : node;
      this.selectedNode = newNodeData;
      this.$emit('node-selected', newNodeData);
      if (typeof this.lf.selectElementById === 'function') {
        this.lf.selectElementById(id);
      }
      if (options.focus !== false && typeof this.lf.focusOn === 'function') {
        this.lf.focusOn({ id });
      }

      this.emitGraphChangeNow();
    },

    defaultNodeData(type) {
      const defaults = {
        trigger: { event_name: 'conversation_created', conditions: [] },
        wait: { duration: 1, unit: 'hours' },
        wait_for_reply: {
          duration: 24,
          unit: 'hours',
          wait_responder: 'contact',
        },
        condition: { conditions: [] },
        action: { action_name: 'send_message', action_params: [''] },
        ai_outreach: { ...AI_OUTREACH_DEFAULTS },
        ai_conversation_analysis: { ...AI_ANALYSIS_DEFAULTS },
        ai_wait_for_intent: { ...AI_WAIT_FOR_INTENT_DEFAULTS },
      };
      return defaults[type] || {};
    },

    updateSelectedNodeProperties(props) {
      if (!this.lf || !this.selectedNode) return;
      // Always fetch the latest data from LogicFlow to avoid stale-property merges
      // when the panel calls this multiple times without a new node:click event.
      const freshData = this.lf.getNodeDataById
        ? this.lf.getNodeDataById(this.selectedNode.id)
        : null;
      const baseProps =
        (freshData && freshData.properties) || this.selectedNode.properties;
      const merged = { ...baseProps, ...props };
      this.lf.setProperties(this.selectedNode.id, merged);
      // Keep Canvas.selectedNode in sync so the next call doesn't use click-time data.
      this.selectedNode = {
        ...(freshData || this.selectedNode),
        properties: merged,
      };
      this.debouncedEmitGraphChange();
    },

    paletteItemTitle(item) {
      return 'Clique para adicionar: ' + (item.label || '');
    },

    nodeColor(type) {
      return getWorkflowNodeVisual(type);
    },

    fitView() {
      if (!this.lf) return;
      this.zoomPercent = fitCanvasView(this.lf);
    },

    zoomIn() {
      this.zoomPercent = zoomCanvasByStep(this.lf, 1);
    },

    zoomOut() {
      this.zoomPercent = zoomCanvasByStep(this.lf, -1);
    },

    resetZoom() {
      this.zoomPercent = resetCanvasZoom(this.lf);
    },

    /** Call before save so debounced graph sync is applied immediately. */
    flushGraphSync() {
      if (this.debouncedEmitGraphChange && this.debouncedEmitGraphChange.flush) {
        this.debouncedEmitGraphChange.flush();
      } else {
        this.emitGraphChangeNow();
      }
    },

    focusNode(nodeId) {
      if (!this.lf || !nodeId) return;
      const nodeData = this.lf.getNodeDataById
        ? this.lf.getNodeDataById(nodeId)
        : null;
      if (!nodeData) return;

      if (typeof this.lf.focusOn === 'function') {
        this.lf.focusOn({ id: nodeId });
      }
      if (typeof this.lf.selectElementById === 'function') {
        this.lf.selectElementById(nodeId);
      }

      this.selectedNode = nodeData;
      this.$emit('node-selected', nodeData);
    },

    focusFirstInvalidNode(nodeIds) {
      const firstId = (nodeIds || [])[0];
      if (firstId) this.focusNode(firstId);
    },
  },
};
</script>

<template>
  <div
    ref="canvasHost"
    class="workflow-canvas-host flex flex-1 min-h-0 overflow-hidden"
    :class="canvasHostClass"
  >
    <!-- Paleta (visual alinhado ao sidebar secundário do app) -->
    <transition name="workflow-palette">
      <aside
        v-if="!readOnly && !paletteCollapsed"
        class="workflow-palette flex-shrink-0 flex flex-col h-full overflow-y-auto w-48 bg-white dark:bg-slate-900 border-r border-slate-50 dark:border-slate-800/50 text-sm px-2 pb-4"
        :aria-label="$t('WORKFLOW.EDITOR.PALETTE_TITLE')"
      >
        <div class="flex items-center justify-between gap-1 px-1 pt-2 pb-1">
          <span class="text-xs font-semibold text-slate-600 dark:text-slate-300 truncate">
            {{ $t('WORKFLOW.EDITOR.PALETTE_TITLE') }}
          </span>
          <button
            type="button"
            class="flex-shrink-0 p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-25 dark:hover:bg-slate-800 transition-all duration-200 ease-smooth cursor-pointer"
            :title="$t('WORKFLOW.EDITOR.PALETTE_COLLAPSE')"
            :aria-label="$t('WORKFLOW.EDITOR.PALETTE_COLLAPSE')"
            @click="paletteCollapsed = true"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
        </div>

        <div class="flex-1 min-h-0">
          <div v-for="(items, group) in paletteGroups" :key="group" class="mt-1">
            <p class="px-2 pt-1.5 pb-1 text-xs font-semibold text-slate-700 dark:text-slate-200">
              {{ group }}
            </p>
            <transition-group name="menu-list" tag="ul" class="list-none m-0 p-0">
              <li
                v-for="item in items"
                :key="item.type"
                class="my-0.5"
              >
                <button
                  type="button"
                  draggable="true"
                  class="workflow-palette-item flex items-center gap-2 w-full p-2 rounded-xl text-sm font-medium leading-4 text-slate-700 dark:text-slate-100 hover:bg-slate-25 dark:hover:bg-slate-800 transition-all duration-200 ease-smooth cursor-grab active:cursor-grabbing"
                  :title="paletteItemTitle(item)"
                  @click="addNode(item)"
                  @dragstart="onPaletteDragStart(item, $event)"
                  @dragend="dragPaletteType = null"
                >
                  <span
                    class="inline-flex items-center justify-center w-5 h-5 rounded-md flex-shrink-0"
                    :style="{ background: nodeColor(item.type).bg }"
                  >
                    <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        :d="nodeColor(item.type).icon" />
                    </svg>
                  </span>
                  <span class="truncate text-left">{{ item.label }}</span>
                </button>
              </li>
            </transition-group>
          </div>

          <div v-if="!isAiFeatureEnabled" class="mt-1">
            <p class="px-2 pt-1.5 pb-1 text-xs font-semibold text-slate-700 dark:text-slate-200">
              {{ $t('WORKFLOW.EDITOR.AI_UPSELL.PALETTE_GROUP') }}
            </p>
            <button
              type="button"
              class="workflow-palette-item flex items-center gap-2 w-full p-2 rounded-xl text-sm font-medium leading-4 text-slate-700 dark:text-slate-100 hover:bg-violet-50/70 dark:hover:bg-violet-950/20 border border-dashed border-violet-200/80 dark:border-violet-800/50 transition-all duration-200 ease-smooth cursor-pointer"
              :title="$t('WORKFLOW.EDITOR.AI_UPSELL.PALETTE_TITLE')"
              @click="showAiUpsellModal = true"
            >
              <span
                class="inline-flex items-center justify-center w-5 h-5 rounded-md flex-shrink-0 bg-violet-500/90"
              >
                <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    :d="nodeColor('ai_outreach').icon" />
                </svg>
              </span>
              <span class="flex flex-col items-start gap-0.5 min-w-0 text-left">
                <span class="truncate">{{ $t('WORKFLOW.EDITOR.NODE_CALL_CLIENT') }}</span>
                <span class="text-[10px] font-normal text-violet-600/90 dark:text-violet-300/90">
                  {{ $t('WORKFLOW.EDITOR.AI_UPSELL.PALETTE_BADGE') }}
                </span>
              </span>
            </button>
          </div>
        </div>

        <p class="px-2 pt-2 text-[11px] leading-relaxed text-slate-400 dark:text-slate-500 text-center">
          {{ $t('WORKFLOW.EDITOR.PALETTE_HINT') }}
        </p>
      </aside>
    </transition>

    <button
      v-if="!readOnly && paletteCollapsed"
      type="button"
      class="workflow-palette-rail flex-shrink-0 flex items-center justify-center w-7 h-full bg-white dark:bg-slate-900 border-r border-slate-50 dark:border-slate-800/50 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-25 dark:hover:bg-slate-800/60 transition-all duration-200 ease-smooth cursor-pointer"
      :title="$t('WORKFLOW.EDITOR.PALETTE_EXPAND')"
      :aria-label="$t('WORKFLOW.EDITOR.PALETTE_EXPAND')"
      @click="paletteCollapsed = false"
    >
      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
      </svg>
    </button>

    <!-- Canvas -->
    <div
      ref="canvasWrapper"
      class="flex-1 relative min-w-0 min-h-0"
      @dragover="onCanvasDragOver"
      @dragleave="onCanvasDragLeave"
      @drop="onCanvasDrop"
    >
      <div ref="canvas" class="w-full h-full absolute inset-0" />
      <div class="workflow-canvas-drop-overlay" aria-hidden="true" />

      <div
        v-if="edgeToolbar && !readOnly && !edgeInsertPicker"
        class="workflow-edge-toolbar"
        :style="{ left: `${edgeToolbar.left}px`, top: `${edgeToolbar.top}px` }"
        @mouseenter="edgeToolbarHovering = true"
        @mouseleave="edgeToolbarHovering = false; scheduleHideEdgeToolbar()"
      >
        <button
          type="button"
          class="workflow-edge-toolbar__btn"
          :title="$t('WORKFLOW.EDITOR.EDGE_INSERT_NODE')"
          :aria-label="$t('WORKFLOW.EDITOR.EDGE_INSERT_NODE')"
          @click.stop="openEdgeInsertPicker"
        >
          <svg width="12" height="12" fill="none" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <button
          type="button"
          class="workflow-edge-toolbar__btn workflow-edge-toolbar__btn--danger"
          :title="$t('WORKFLOW.EDITOR.EDGE_DELETE')"
          :aria-label="$t('WORKFLOW.EDITOR.EDGE_DELETE')"
          @click.stop="deleteHoveredEdge"
        >
          <svg width="12" height="12" fill="none" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>

      <!-- n8n stub: traço + "+" (click = picker, drag = connect) -->
      <svg
        v-if="showOutputStubs || connectPreview"
        class="workflow-output-stubs"
        aria-hidden="true"
      >
        <line
          v-for="stub in outputStubs"
          :key="`line-${stub.nodeId}-${stub.sourceAnchorId}`"
          :x1="stub.x1"
          :y1="stub.y1"
          :x2="stub.x2"
          :y2="stub.y2"
          class="workflow-output-stubs__line"
        />
        <circle
          v-for="stub in outputStubs"
          :key="`dot-${stub.nodeId}-${stub.sourceAnchorId}`"
          :cx="stub.x1"
          :cy="stub.y1"
          r="5"
          class="workflow-output-stubs__dot"
        />
        <circle
          v-for="hint in connectTargetHints"
          :key="`hint-${hint.nodeId}`"
          :cx="hint.cx"
          :cy="hint.cy"
          :r="connectHoverNodeId === hint.nodeId ? 7 : 5"
          class="workflow-output-stubs__target-dot"
          :class="{ 'is-active': connectHoverNodeId === hint.nodeId }"
        />
        <line
          v-if="connectPreview"
          :x1="connectPreview.x1"
          :y1="connectPreview.y1"
          :x2="connectPreview.x2"
          :y2="connectPreview.y2"
          class="workflow-output-stubs__preview"
        />
      </svg>
      <button
        v-for="stub in outputStubs"
        v-show="showOutputStubs"
        :key="`plus-${stub.nodeId}-${stub.sourceAnchorId}`"
        type="button"
        class="workflow-stub-plus"
        :class="{ 'is-connecting': !!connectPreview }"
        :style="{ left: `${stub.plusLeft}px`, top: `${stub.plusTop}px` }"
        :title="$t('WORKFLOW.EDITOR.NODE_ADD_NEXT')"
        :aria-label="$t('WORKFLOW.EDITOR.NODE_ADD_NEXT')"
        @pointerdown="onStubPlusPointerDown(stub, $event)"
      >
        <svg width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4" />
        </svg>
      </button>

      <!-- Node hover trash -->
      <button
        v-if="hoveredNode && !readOnly"
        type="button"
        class="workflow-node-trash"
        :style="{ left: `${hoveredNode.left}px`, top: `${hoveredNode.top}px` }"
        :title="$t('WORKFLOW.EDITOR.NODE_DELETE')"
        :aria-label="$t('WORKFLOW.EDITOR.NODE_DELETE')"
        @mouseenter="keepNodeHover"
        @mouseleave="scheduleHideNodeHover"
        @click.stop="deleteHoveredNode"
      >
        <svg width="12" height="12" fill="none" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
        </svg>
      </button>

      <div
        v-if="edgeInsertPicker && !readOnly"
        class="workflow-edge-insert-picker"
        :class="{ 'workflow-edge-insert-picker--node': edgeInsertPicker.mode === 'node' }"
        :style="{ left: `${edgeInsertPicker.left}px`, top: `${edgeInsertPicker.top}px` }"
        role="dialog"
        tabindex="-1"
        :aria-label="$t('WORKFLOW.EDITOR.EDGE_INSERT_PICKER_TITLE')"
        @mouseenter="edgeToolbarHovering = true"
        @mouseleave="edgeToolbarHovering = false"
        @keydown="onEdgeInsertPickerKeydown"
      >
        <div class="workflow-edge-insert-picker__header">
          <span class="workflow-edge-insert-picker__title">
            {{ $t('WORKFLOW.EDITOR.EDGE_INSERT_PICKER_TITLE') }}
          </span>
          <button
            type="button"
            class="workflow-edge-insert-picker__close"
            :aria-label="$t('WORKFLOW.EDITOR.EDGE_INSERT_PICKER_CLOSE')"
            @click.stop="closeEdgeInsertPicker"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <ul class="workflow-edge-insert-picker__list" role="listbox">
          <li v-for="item in insertablePaletteItems" :key="item.type">
            <button
              type="button"
              class="workflow-edge-insert-picker__item"
              role="option"
              @click.stop="selectEdgeInsertType(item)"
            >
              <span
                class="workflow-edge-insert-picker__icon"
                :style="{ background: nodeColor(item.type).bg }"
                aria-hidden="true"
              >
                <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    :d="nodeColor(item.type).icon"
                  />
                </svg>
              </span>
              <span class="truncate">{{ item.label }}</span>
            </button>
          </li>
        </ul>
      </div>

      <div class="workflow-canvas-zoom-controls">
        <button
          type="button"
          class="workflow-canvas-zoom-controls__btn"
          :title="$t('WORKFLOW.EDITOR.ZOOM_OUT')"
          :aria-label="$t('WORKFLOW.EDITOR.ZOOM_OUT')"
          @click="zoomOut"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
          </svg>
        </button>
        <button
          type="button"
          class="workflow-canvas-zoom-controls__level"
          :title="$t('WORKFLOW.EDITOR.ZOOM_RESET')"
          :aria-label="$t('WORKFLOW.EDITOR.ZOOM_RESET')"
          @click="resetZoom"
        >
          {{ zoomPercent }}%
        </button>
        <button
          type="button"
          class="workflow-canvas-zoom-controls__btn"
          :title="$t('WORKFLOW.EDITOR.ZOOM_IN')"
          :aria-label="$t('WORKFLOW.EDITOR.ZOOM_IN')"
          @click="zoomIn"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <span class="workflow-canvas-zoom-controls__divider" aria-hidden="true" />
        <button
          type="button"
          class="workflow-canvas-zoom-controls__btn"
          :title="$t('WORKFLOW.EDITOR.FIT_VIEW')"
          :aria-label="$t('WORKFLOW.EDITOR.FIT_VIEW')"
          @click="fitView"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
            />
          </svg>
        </button>
      </div>

    </div>

    <WorkflowAiUpsellModal
      :show="showAiUpsellModal"
      @close="showAiUpsellModal = false"
    />
  </div>
</template>

<style scoped>
.workflow-palette-item:active {
  transform: scale(0.985);
}

.workflow-palette-enter-active,
.workflow-palette-leave-active {
  transition:
    width 0.25s var(--ease-out-cubic, cubic-bezier(0.33, 1, 0.68, 1)),
    opacity 0.2s var(--ease-out-cubic, cubic-bezier(0.33, 1, 0.68, 1)),
    transform 0.2s var(--ease-out-cubic, cubic-bezier(0.33, 1, 0.68, 1));
  overflow: hidden;
}

.workflow-palette-enter,
.workflow-palette-leave-to {
  width: 0;
  opacity: 0;
  transform: translateX(-0.375rem);
}

.workflow-palette-enter-to,
.workflow-palette-leave {
  width: 12rem;
  opacity: 1;
  transform: translateX(0);
}

@media (prefers-reduced-motion: reduce) {
  .workflow-palette-enter-active,
  .workflow-palette-leave-active {
    transition: none;
  }

  .workflow-palette-item:active {
    transform: none;
  }
}
</style>
