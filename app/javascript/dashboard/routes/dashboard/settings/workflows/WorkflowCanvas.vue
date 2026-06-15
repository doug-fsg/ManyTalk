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
import { WORKFLOW_CANVAS_GRID_SIZE, WORKFLOW_NODE_PALETTE, AI_OUTREACH_DEFAULTS, AI_ANALYSIS_DEFAULTS } from './constants';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { mapGetters } from 'vuex';
import WorkflowAiUpsellModal from './WorkflowAiUpsellModal.vue';
import {
  registerWorkflowNodes,
  getLogicFlowTheme,
  WORKFLOW_LF_NODE_TYPE,
  isBranchNodeType,
  anchorIdToSourceHandle,
  sourceHandleLabel,
  workflowAnchorInId,
  workflowAnchorOutId,
  workflowAnchorOutTrueId,
  workflowAnchorOutFalseId,
  isWorkflowCanvasDark,
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
      zoomPercent: 100,
      showAiUpsellModal: false,
    };
  },
  created() {
    this.debouncedEmitGraphChange = debounce(this.emitGraphChangeNow, 300);
    this.debouncedResizeCanvas = debounce(this.resizeCanvasNow, 150);
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
    canvasHostClass() {
      const classes = [this.isDarkMode ? 'workflow-canvas--dark' : 'workflow-canvas--light'];
      if (this.isDropActive) classes.push('workflow-canvas-host--drop-active');
      return classes.join(' ');
    },
  },
  watch: {
    graphRevision() {
      this.renderGraph();
    },
    isDarkMode() {
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

      this.lf.on('edge:mouseenter', ({ data }) => {
        this.onEdgeMouseEnter(data);
      });
      this.lf.on('edge:mouseleave', () => {
        this.scheduleHideEdgeToolbar();
      });
      this.lf.on('graph:transform', () => {
        this.syncZoomLevel();
        if (this.edgeToolbar && this.edgeToolbar.edgeId) {
          this.updateEdgeToolbarPosition(this.edgeToolbar.edgeId);
        }
      });
    },

    onEdgeMouseEnter(edgeData) {
      if (this.readOnly || !edgeData) return;
      if (this.edgeToolbarHideTimer) {
        clearTimeout(this.edgeToolbarHideTimer);
        this.edgeToolbarHideTimer = null;
      }
      this.edgeToolbar = { edgeId: edgeData.id };
      this.updateEdgeToolbarPosition(edgeData.id);
    },

    scheduleHideEdgeToolbar() {
      if (this.edgeToolbarHovering) return;
      if (this.edgeToolbarHideTimer) clearTimeout(this.edgeToolbarHideTimer);
      this.edgeToolbarHideTimer = setTimeout(() => {
        if (!this.edgeToolbarHovering) this.edgeToolbar = null;
      }, 320);
    },

    hideEdgeToolbar() {
      this.edgeToolbarHovering = false;
      this.edgeToolbar = null;
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

    insertNodeOnHoveredEdge() {
      if (!this.lf || !this.edgeToolbar || this.readOnly) return;

      const edgeId = this.edgeToolbar.edgeId;
      const edgeModel = this.lf.getEdgeModelById(edgeId);
      if (!edgeModel) return;

      const edgeData = edgeModel.getData ? edgeModel.getData() : edgeModel;
      const sourceId = edgeData.sourceNodeId;
      const targetId = edgeData.targetNodeId;
      const sourceAnchorId = this.resolveEdgeSourceAnchorId(edgeData);

      const mx =
        (edgeModel.startPoint.x + edgeModel.endPoint.x) / 2;
      const my =
        (edgeModel.startPoint.y + edgeModel.endPoint.y) / 2;

      const paletteItem =
        WORKFLOW_NODE_PALETTE.find(item => item.type === 'action') ||
        WORKFLOW_NODE_PALETTE[WORKFLOW_NODE_PALETTE.length - 1];
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

      this.lf.createEdge({
        type: WORKFLOW_EDGE_TYPE,
        sourceNodeId: sourceId,
        targetNodeId: newId,
        sourceAnchorId,
        targetAnchorId: workflowAnchorInId(newId),
      });

      this.lf.createEdge({
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

      const rect = this.$refs.canvas.getBoundingClientRect();
      const point = this.lf.getPointByClient({
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
      });
      this.addNodeAt(paletteItem, point.x, point.y);
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
      this.lf.updateEditConfig({ isSilentMode: readOnly });
      if (this.lf.keyboard) {
        if (readOnly) this.lf.keyboard.disable();
        else this.lf.keyboard.enable(true);
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
      if (snapshot === this.lastSyncedGraphSnapshot) return;

      this.lastSyncedGraphSnapshot = snapshot;
      this.$emit('update:graph', graph);
    },

    getGraphForSave() {
      return exportGraphFromLogicFlow(this.lf, this.graph);
    },

    isAiNodeType(type) {
      return type === 'ai_outreach' || type === 'ai_conversation_analysis';
    },

    addNode(paletteItem) {
      if (this.isAiNodeType(paletteItem.type) && !this.isAiFeatureEnabled) {
        this.showAiUpsellModal = true;
        return;
      }
      this.addNodeAt(
        paletteItem,
        300 + Math.random() * 120,
        200 + Math.random() * 120
      );
    },

    addNodeAt(paletteItem, x, y) {
      if (!this.lf || this.readOnly) return;
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
      this.emitGraphChangeNow();
    },

    defaultNodeData(type) {
      const defaults = {
        trigger: { event_name: 'conversation_created', conditions: [] },
        wait: { duration: 1, unit: 'hours' },
        wait_for_reply: {
          duration: 24,
          unit: 'hours',
          label: 'Aguardar resposta',
          wait_responder: 'contact',
        },
        condition: { conditions: [] },
        action: { action_name: 'send_message', action_params: [''] },
        ai_outreach: { ...AI_OUTREACH_DEFAULTS },
        ai_conversation_analysis: { ...AI_ANALYSIS_DEFAULTS },
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
      this.emitGraphChangeNow();
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
    <!-- Paleta -->
    <transition name="palette">
      <div
        v-if="!readOnly && !paletteCollapsed"
        class="w-52 flex-shrink-0 flex flex-col border-r border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 overflow-y-auto"
      >
        <div class="flex items-center justify-between px-3 py-2.5 border-b border-slate-200 dark:border-slate-700">
          <span class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
            {{ $t('WORKFLOW.EDITOR.PALETTE_TITLE') }}
          </span>
          <button
            type="button"
            class="p-1 rounded text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
            @click="paletteCollapsed = true"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
        </div>

        <div class="flex-1 p-2 space-y-3">
          <div v-for="(items, group) in paletteGroups" :key="group">
            <p class="px-2 mb-1 text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              {{ group }}
            </p>
            <button
              v-for="item in items"
              :key="item.type"
              type="button"
              draggable="true"
              class="flex items-center gap-2.5 w-full px-3 py-2.5 mb-1 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors duration-150 cursor-grab active:cursor-grabbing min-h-[44px]"
              :title="paletteItemTitle(item)"
              @click="addNode(item)"
              @dragstart="onPaletteDragStart(item, $event)"
              @dragend="dragPaletteType = null"
            >
              <span
                class="w-7 h-7 rounded-md flex items-center justify-center flex-shrink-0"
                :style="{ background: nodeColor(item.type).bg }"
              >
                <svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    :d="nodeColor(item.type).icon" />
                </svg>
              </span>
              {{ item.label }}
            </button>
          </div>

          <div v-if="!isAiFeatureEnabled">
            <p class="px-2 mb-1 text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              {{ $t('WORKFLOW.EDITOR.AI_UPSELL.PALETTE_GROUP') }}
            </p>
            <button
              type="button"
              class="flex items-center gap-2.5 w-full px-3 py-2.5 mb-1 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-300 border border-dashed border-violet-300 dark:border-violet-700 hover:bg-violet-50 dark:hover:bg-violet-950/30 transition-colors duration-150 cursor-pointer min-h-[44px]"
              :title="$t('WORKFLOW.EDITOR.AI_UPSELL.PALETTE_TITLE')"
              @click="showAiUpsellModal = true"
            >
              <span
                class="w-7 h-7 rounded-md flex items-center justify-center flex-shrink-0 bg-violet-600/90"
              >
                <svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    :d="nodeColor('ai_outreach').icon" />
                </svg>
              </span>
              <span class="flex flex-col items-start gap-0.5 min-w-0 text-left">
                <span>{{ $t('WORKFLOW.EDITOR.NODE_CALL_CLIENT') }}</span>
                <span class="text-[11px] font-normal text-violet-600 dark:text-violet-300">
                  {{ $t('WORKFLOW.EDITOR.AI_UPSELL.PALETTE_BADGE') }}
                </span>
              </span>
            </button>
          </div>
        </div>

        <div class="p-3 border-t border-slate-200 dark:border-slate-700">
          <p class="text-xs text-slate-500 dark:text-slate-400 text-center">
            {{ $t('WORKFLOW.EDITOR.PALETTE_HINT') }}
          </p>
        </div>
      </div>
    </transition>

    <button
      v-if="!readOnly && paletteCollapsed"
      type="button"
      class="w-8 flex-shrink-0 flex items-center justify-center bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-700 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition-colors cursor-pointer"
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
        v-if="edgeToolbar && !readOnly"
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
          @click.stop="insertNodeOnHoveredEdge"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.25" d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <button
          type="button"
          class="workflow-edge-toolbar__btn workflow-edge-toolbar__btn--danger"
          :title="$t('WORKFLOW.EDITOR.EDGE_DELETE')"
          :aria-label="$t('WORKFLOW.EDITOR.EDGE_DELETE')"
          @click.stop="deleteHoveredEdge"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.25" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
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

      <div
        v-if="readOnly"
        role="status"
        aria-live="polite"
        class="absolute top-4 left-1/2 -translate-x-1/2 px-3 py-1.5 bg-amber-100 dark:bg-amber-900/80 text-amber-800 dark:text-amber-200 text-xs font-medium rounded-full border border-amber-200 dark:border-amber-700 z-10 pointer-events-none"
      >
        {{ $t('WORKFLOW.EDITOR.ACTIVE_READONLY') }}
      </div>
    </div>

    <WorkflowAiUpsellModal
      :show="showAiUpsellModal"
      @close="showAiUpsellModal = false"
    />
  </div>
</template>

<style scoped>
.palette-enter-active,
.palette-leave-active {
  transition: width 0.2s ease, opacity 0.15s ease;
  overflow: hidden;
}
.palette-enter,
.palette-leave-to {
  width: 0;
  opacity: 0;
}
.palette-enter-to,
.palette-leave {
  width: 13rem;
  opacity: 1;
}
@media (prefers-reduced-motion: reduce) {
  .palette-enter-active,
  .palette-leave-active {
    transition: none;
  }
}
</style>
