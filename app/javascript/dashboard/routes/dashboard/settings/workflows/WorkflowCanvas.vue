<script>
import LogicFlow from '@logicflow/core';
import '@logicflow/core/dist/style/index.css';
import debounce from 'lodash/debounce';
import './workflow-canvas.scss';
import {
  exportGraphFromLogicFlow,
  graphToLogicFlowData,
  nextNodeId,
  workflowGraphSnapshot,
} from 'dashboard/helper/workflowGraphHelper';
import { WORKFLOW_NODE_PALETTE } from './constants';
import {
  registerWorkflowNodes,
  getLogicFlowTheme,
  WORKFLOW_LF_NODE_TYPE,
} from './workflowLogicFlowNodes';

const NODE_COLORS = {
  trigger: { bg: '#2563EB', icon: 'M13 10V3L4 14h7v7l9-11h-7z' },
  wait: { bg: '#7C3AED', icon: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z' },
  condition: { bg: '#D97706', icon: 'M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' },
  action: { bg: '#059669', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z' },
};

export default {
  name: 'WorkflowCanvas',
  props: {
    graph: { type: Object, required: true },
    /** Bumped when graph is loaded from API so canvas re-renders once. */
    graphRevision: { type: Number, default: 0 },
    readOnly: { type: Boolean, default: false },
  },
  data() {
    return {
      lf: null,
      selectedNode: null,
      paletteCollapsed: false,
      isDarkMode: document.body.classList.contains('dark'),
      suspendGraphSync: false,
      lastSyncedGraphSnapshot: null,
    };
  },
  created() {
    this.debouncedEmitGraphChange = debounce(this.emitGraphChangeNow, 300);
    this.debouncedResizeCanvas = debounce(this.resizeCanvasNow, 150);
  },
  computed: {
    paletteGroups() {
      const groups = {};
      WORKFLOW_NODE_PALETTE.forEach(item => {
        if (!groups[item.group]) groups[item.group] = [];
        groups[item.group].push(item);
      });
      return groups;
    },
    canvasHostClass() {
      return this.isDarkMode ? 'workflow-canvas--dark' : 'workflow-canvas--light';
    },
  },
  watch: {
    graphRevision() {
      this.renderGraph();
    },
    isDarkMode() { this.applyTheme(); },
    readOnly(val) {
      this.applyReadOnlyMode(val);
    },
  },
  mounted() {
    this.themeObserver = new MutationObserver(() => {
      const dark = document.body.classList.contains('dark');
      if (dark !== this.isDarkMode) {
        this.isDarkMode = dark;
      }
    });
    this.themeObserver.observe(document.body, {
      attributes: true,
      attributeFilter: ['class'],
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
        grid: { visible: true, type: 'dot', size: 20 },
        keyboard: { enabled: !this.readOnly },
        isSilentMode: this.readOnly,
        edgeType: 'polyline',
        adjustNodePosition: true,
        textEdit: false,
      });
      registerWorkflowNodes(this.lf);
      this.applyTheme();

      this.lf.on('node:click', ({ data }) => {
        this.selectedNode = data;
        this.$emit('node-selected', data);
      });
      this.lf.on('blank:click', () => {
        this.selectedNode = null;
        this.$emit('node-selected', null);
      });
      this.lf.on('history:change', () => { this.debouncedEmitGraphChange(); });
    },

    applyTheme() {
      if (!this.lf) return;
      this.lf.setTheme(getLogicFlowTheme(this.isDarkMode));
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
      }
    },

    renderGraph() {
      if (!this.lf) return;
      this.suspendGraphSync = true;
      const data = graphToLogicFlowData(this.graph);
      this.lf.render(data);
      this.$nextTick(() => {
        this.resizeCanvasNow();
        this.suspendGraphSync = false;
        this.emitGraphChangeNow();
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

    addNode(paletteItem) {
      if (!this.lf || this.readOnly) return;
      const id = nextNodeId();
      const defaultData = this.defaultNodeData(paletteItem.type);
      const node = {
        id,
        type: WORKFLOW_LF_NODE_TYPE,
        x: 300 + Math.random() * 120,
        y: 200 + Math.random() * 120,
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
        condition: { conditions: [] },
        action: { action_name: 'send_message', action_params: [''] },
      };
      return defaults[type] || {};
    },

    updateSelectedNodeProperties(props) {
      if (!this.lf || !this.selectedNode) return;
      const merged = { ...this.selectedNode.properties, ...props };
      this.lf.setProperties(this.selectedNode.id, merged);
      this.emitGraphChangeNow();
    },

    paletteItemTitle(item) {
      return 'Clique para adicionar: ' + (item.label || '');
    },

    nodeColor(type) {
      return NODE_COLORS[type] || NODE_COLORS.action;
    },

    fitView() {
      if (this.lf) this.lf.fitView();
    },

    /** Call before save so debounced graph sync is applied immediately. */
    flushGraphSync() {
      if (this.debouncedEmitGraphChange && this.debouncedEmitGraphChange.flush) {
        this.debouncedEmitGraphChange.flush();
      } else {
        this.emitGraphChangeNow();
      }
    },
  },
};
</script>

<template>
  <div
    ref="canvasHost"
    class="workflow-canvas-host flex flex-1 min-h-0 overflow-hidden bg-slate-50 dark:bg-slate-950"
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
              class="flex items-center gap-2.5 w-full px-3 py-2.5 mb-1 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors duration-150 cursor-pointer min-h-[44px]"
              :title="paletteItemTitle(item)"
              @click="addNode(item)"
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
    <div class="flex-1 relative min-w-0 min-h-0">
      <div ref="canvas" class="w-full h-full absolute inset-0" />

      <div class="absolute bottom-4 right-4 flex flex-col gap-2 z-10">
        <button
          type="button"
          class="flex items-center gap-2 px-3 py-2 text-xs font-medium text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg shadow-sm transition-colors cursor-pointer min-h-[36px]"
          @click="fitView"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
          </svg>
          {{ $t('WORKFLOW.EDITOR.FIT_VIEW') }}
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
