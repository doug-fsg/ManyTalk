<script setup>
import { computed, defineAsyncComponent, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import WorkflowsAPI from 'dashboard/api/workflows';
import WorkflowPropertiesPanel from './WorkflowPropertiesPanel.vue';
import {
  emptyGraph,
  serializeGraphForApi,
} from 'dashboard/helper/workflowGraphHelper';

const WorkflowCanvas = defineAsyncComponent(() => import('./WorkflowCanvas.vue'));

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const workflow = ref({ name: '', description: '', active: false, graph: emptyGraph() });
/** Last `active` value persisted on the server (not draft toggle). */
const activeSaved = ref(false);
const selectedNode = ref(null);
const isDirty = ref(false);
const isSaving = ref(false);
const isLoading = ref(false);
const loadError = ref(null);
const validationErrors = ref([]);
const canvasRef = ref(null);
const graphRevision = ref(0);

const workflowId = computed(() => route.params.workflowId);
const isEdit = computed(() => Boolean(workflowId.value));
const readOnlyGraph = computed(
  () => isEdit.value && activeSaved.value === true && !isDirty.value
);

const saveStatusIcon = computed(() => {
  if (isSaving.value) return 'saving';
  if (isDirty.value) return 'unsaved';
  return 'saved';
});

const saveStatusLabel = computed(() => {
  const map = {
    saving: t('WORKFLOW.EDITOR.SAVING'),
    unsaved: t('WORKFLOW.EDITOR.UNSAVED'),
    saved: t('WORKFLOW.EDITOR.SAVED'),
  };
  return map[saveStatusIcon.value];
});

const loadWorkflow = async () => {
  if (!workflowId.value) {
    workflow.value.graph = emptyGraph();
    activeSaved.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    const response = await WorkflowsAPI.show(workflowId.value);
    workflow.value = { ...response.data, graph: response.data.graph || emptyGraph() };
    activeSaved.value = Boolean(response.data.active);
    graphRevision.value += 1;
    isDirty.value = false;
  } catch {
    loadError.value = t('WORKFLOW.EDITOR.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  loadWorkflow();
});

watch(workflowId, loadWorkflow);

const markDirty = () => { isDirty.value = true; };

const onWorkflowActiveInput = value => {
  workflow.value.active = value;
  markDirty();
};
const onGraphUpdate = graph => { workflow.value.graph = graph; markDirty(); };
const onNodeSelected = node => { selectedNode.value = node; };

const onUpdateNode = props => {
  if (!selectedNode.value || !canvasRef.value) return;
  canvasRef.value.updateSelectedNodeProperties(props);
  selectedNode.value = {
    ...selectedNode.value,
    properties: { ...selectedNode.value.properties, ...props },
  };
};

const onUpdateSettings = settings => {
  workflow.value.graph = { ...workflow.value.graph, settings };
  markDirty();
};

const save = async (activate = false) => {
  isSaving.value = true;
  validationErrors.value = [];
  try {
    if (canvasRef.value && canvasRef.value.flushGraphSync) {
      canvasRef.value.flushGraphSync();
    }
    const rawGraph =
      canvasRef.value && canvasRef.value.getGraphForSave
        ? canvasRef.value.getGraphForSave()
        : workflow.value.graph;
    const graph = serializeGraphForApi(rawGraph);

    const payload = {
      name: workflow.value.name,
      description: workflow.value.description,
      active: activate ? true : workflow.value.active,
      graph,
    };
    if (isEdit.value) {
      const updated = await store.dispatch('workflows/update', {
        id: workflowId.value,
        ...payload,
      });
      workflow.value = { ...workflow.value, ...updated };
      activeSaved.value = Boolean(updated.active);
    } else {
      const created = await store.dispatch('workflows/create', payload);
      workflow.value = { ...workflow.value, ...created };
      activeSaved.value = Boolean(created.active);
      router.replace({ name: 'workflows_edit', params: { workflowId: created.id } });
    }
    isDirty.value = false;
    useAlert(t('WORKFLOW.EDITOR.SAVE_SUCCESS'));
  } catch (e) {
    const err = e && e.response && e.response.data && e.response.data.error;
    validationErrors.value = Array.isArray(err) ? err : [err || t('WORKFLOW.EDITOR.SAVE_ERROR')];
    useAlert(t('WORKFLOW.EDITOR.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const goBack = () => router.push({ name: 'workflows_list' });

const workflowNameInputId = 'workflow-editor-name';
const workflowActiveLabelId = 'workflow-editor-active-label';
const workflowActiveSwitchLabel = computed(() =>
  workflow.value.active
    ? t('WORKFLOW.EDITOR.ACTIVE_SWITCH_ON')
    : t('WORKFLOW.EDITOR.ACTIVE_SWITCH_OFF')
);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 h-full overflow-hidden bg-white dark:bg-slate-900">
    <!-- Toolbar -->
    <div
      class="flex flex-wrap items-center gap-2 sm:gap-3 px-3 sm:px-4 min-h-14 py-2 flex-shrink-0 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 z-10"
    >
      <button
        type="button"
        class="flex items-center gap-1.5 text-sm text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors cursor-pointer"
        @click="goBack"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        {{ $t('WORKFLOW.EDITOR.BACK') }}
      </button>

      <div class="w-px h-5 bg-slate-200 dark:bg-slate-700" />

      <div class="flex-1 min-w-0 flex items-center gap-2 basis-full sm:basis-auto">
        <label
          :for="workflowNameInputId"
          class="sr-only"
        >{{ $t('WORKFLOW.EDITOR.NAME_PLACEHOLDER') }}</label>
        <input
          :id="workflowNameInputId"
          v-model="workflow.name"
          type="text"
          class="flex-1 max-w-md text-sm font-semibold text-slate-900 dark:text-slate-50 bg-transparent border-0 focus:outline-none focus:ring-2 focus:ring-woot-500/40 rounded px-2 py-1 placeholder-slate-400"
          :placeholder="$t('WORKFLOW.EDITOR.NAME_PLACEHOLDER')"
          @input="markDirty"
        />

        <div class="flex items-center gap-1.5 shrink-0">
          <template v-if="saveStatusIcon === 'saving'">
            <div
              class="w-3.5 h-3.5 border-2 border-woot-500 border-t-transparent rounded-full animate-spin workflow-editor-toolbar-spinner"
              aria-hidden="true"
            />
          </template>
          <template v-else-if="saveStatusIcon === 'unsaved'">
            <div class="w-2 h-2 rounded-full bg-amber-400" />
          </template>
          <template v-else>
            <svg class="w-3.5 h-3.5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
            </svg>
          </template>
          <span class="text-xs text-slate-500 dark:text-slate-400">{{ saveStatusLabel }}</span>
        </div>
      </div>

      <div
        class="flex items-center gap-2 shrink-0 mr-1 sm:mr-2 pr-2 sm:pr-3 border-r border-slate-200 dark:border-slate-700"
        :class="{ 'pointer-events-none opacity-60': isSaving }"
        role="group"
        :aria-labelledby="workflowActiveLabelId"
      >
        <span
          :id="workflowActiveLabelId"
          class="text-xs font-medium text-slate-600 dark:text-slate-400 whitespace-nowrap hidden sm:inline"
        >
          {{ $t('WORKFLOW.EDITOR.WORKFLOW_ACTIVE') }}
        </span>
        <woot-switch
          :value="workflow.active"
          size="small"
          :aria-label="workflowActiveSwitchLabel"
          @input="onWorkflowActiveInput"
        />
        <span
          class="text-xs font-medium tabular-nums sm:hidden"
          :class="workflow.active ? 'text-green-600 dark:text-green-400' : 'text-slate-500 dark:text-slate-400'"
        >
          {{ workflow.active ? $t('WORKFLOW.LIST.ACTIVE') : $t('WORKFLOW.LIST.INACTIVE') }}
        </span>
      </div>

      <div class="flex items-center gap-2 shrink-0">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          :is-loading="isSaving"
          @click="save(false)"
        >
          {{ $t('WORKFLOW.EDITOR.SAVE') }}
        </woot-button>
        <woot-button
          variant="smooth"
          color-scheme="primary"
          size="small"
          :is-loading="isSaving"
          @click="save(true)"
        >
          {{ $t('WORKFLOW.EDITOR.SAVE_AND_ACTIVATE') }}
        </woot-button>
      </div>
    </div>

    <transition name="fade-down">
      <div
        v-if="validationErrors.length"
        class="mx-4 mt-3 p-3 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800"
        role="alert"
      >
        <ul class="text-xs text-red-700 dark:text-red-300 space-y-1">
          <li v-for="(err, i) in validationErrors" :key="i">{{ err }}</li>
        </ul>
      </div>
    </transition>

    <div
      v-if="loadError"
      class="flex items-center justify-center flex-1 flex-col gap-3"
    >
      <p class="text-sm text-slate-500">{{ loadError }}</p>
      <button
        type="button"
        class="text-sm text-woot-500 hover:text-woot-600 cursor-pointer"
        @click="loadWorkflow"
      >
        {{ $t('WORKFLOW.EDITOR.RETRY') }}
      </button>
    </div>

    <div v-else-if="isLoading" class="flex items-center justify-center flex-1">
      <div class="flex flex-col items-center gap-3">
        <div class="w-7 h-7 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
        <p class="text-sm text-slate-500">{{ $t('WORKFLOW.EDITOR.LOADING') }}</p>
      </div>
    </div>

    <div v-else class="flex flex-1 min-h-0 overflow-hidden">
      <WorkflowCanvas
        ref="canvasRef"
        :graph="workflow.graph"
        :graph-revision="graphRevision"
        :read-only="readOnlyGraph"
        @update:graph="onGraphUpdate"
        @node-selected="onNodeSelected"
      />
      <WorkflowPropertiesPanel
        :node="selectedNode"
        :graph-settings="workflow.graph.settings"
        :read-only="readOnlyGraph"
        @update-node="onUpdateNode"
        @update-settings="onUpdateSettings"
      />
    </div>
  </div>
</template>

<style scoped>
.fade-down-enter-active,
.fade-down-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.fade-down-enter,
.fade-down-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
@media (prefers-reduced-motion: reduce) {
  .fade-down-enter-active,
  .fade-down-leave-active {
    transition: none;
  }
  .workflow-editor-toolbar-spinner {
    animation: none;
    border-top-color: transparent;
    opacity: 0.85;
  }
}
</style>
