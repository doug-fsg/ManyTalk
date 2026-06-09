<script setup>
import {
  computed,
  defineAsyncComponent,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useRoute, useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import WorkflowsAPI from 'dashboard/api/workflows';
import BackButton from 'dashboard/components/widgets/BackButton.vue';
import WorkflowPropertiesPanel from './WorkflowPropertiesPanel.vue';
import WorkflowFlowSettingsPanel from './WorkflowFlowSettingsPanel.vue';
import {
  emptyGraph,
  serializeGraphForApi,
  normalizeWorkflowGraph,
  extractInvalidNodeIds,
  validationErrorMessages,
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
const invalidNodeIds = ref([]);
const nameError = ref(false);
const canvasRef = ref(null);
const graphRevision = ref(0);
const showFlowSettings = ref(false);
const isTogglingActive = ref(false);

const workflowId = computed(() => route.params.workflowId);
const isEdit = computed(() => Boolean(workflowId.value));
const readOnlyGraph = computed(
  () => isEdit.value && activeSaved.value === true && !isDirty.value
);

const saveAndActivateDisabled = computed(() => validationErrors.value.length > 0);

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
    workflow.value = {
      ...response.data,
      graph: normalizeWorkflowGraph(response.data.graph || emptyGraph()),
    };
    activeSaved.value = Boolean(response.data.active);
    graphRevision.value += 1;
    isDirty.value = false;
  } catch {
    loadError.value = t('WORKFLOW.EDITOR.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const handleBeforeUnload = e => {
  if (isDirty.value) {
    e.preventDefault();
    e.returnValue = '';
  }
};

const removeRouteGuard = router.beforeEach((to, from, next) => {
  if (isDirty.value && from.name === 'workflows_edit') {
    const answer = window.confirm(t('WORKFLOW.EDITOR.UNSAVED_LEAVE_CONFIRM'));
    if (!answer) return next(false);
  }
  return next();
});

onMounted(() => {
  loadWorkflow();
  window.addEventListener('beforeunload', handleBeforeUnload);
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', handleBeforeUnload);
  removeRouteGuard();
});

watch(workflowId, loadWorkflow);

const markDirty = () => {
  isDirty.value = true;
  if (nameError.value) nameError.value = false;
};

const onWorkflowActiveInput = async value => {
  if (!isEdit.value) {
    workflow.value.active = value;
    markDirty();
    return;
  }

  if (isTogglingActive.value || value === activeSaved.value) {
    workflow.value.active = value;
    return;
  }

  isTogglingActive.value = true;
  const previousActive = activeSaved.value;
  workflow.value.active = value;

  try {
    const updated = await store.dispatch('workflows/update', {
      id: workflowId.value,
      active: value,
    });
    workflow.value.active = Boolean(updated.active);
    activeSaved.value = Boolean(updated.active);
    useAlert(t('WORKFLOW.TOGGLE.SUCCESS'));
  } catch {
    workflow.value.active = previousActive;
    useAlert(t('WORKFLOW.TOGGLE.ERROR'));
  } finally {
    isTogglingActive.value = false;
  }
};
const onGraphUpdate = graph => {
  workflow.value.graph = graph;
  markDirty();
  validationErrors.value = [];
  invalidNodeIds.value = [];
};
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

const openFlowSettings = () => {
  showFlowSettings.value = true;
};

const closeFlowSettings = () => {
  showFlowSettings.value = false;
};

const save = async (activate = false) => {
  validationErrors.value = [];
  invalidNodeIds.value = [];
  nameError.value = false;

  const trimmedName = (workflow.value.name || '').trim();
  if (!trimmedName) {
    nameError.value = true;
    useAlert(t('WORKFLOW.EDITOR.NAME_REQUIRED'));
    await nextTick();
    const nameInput = document.getElementById(workflowNameInputId);
    if (nameInput) nameInput.focus();
    return;
  }

  isSaving.value = true;
  try {
    if (canvasRef.value && canvasRef.value.flushGraphSync) {
      canvasRef.value.flushGraphSync();
    }
    const rawGraph =
      canvasRef.value && canvasRef.value.getGraphForSave
        ? canvasRef.value.getGraphForSave()
        : workflow.value.graph;
    const graph = serializeGraphForApi(rawGraph);

    const validationResponse = await WorkflowsAPI.validate(graph);
    const validationResult = validationResponse.data || {};
    if (!validationResult.valid) {
      validationErrors.value = validationErrorMessages(validationResult.errors);
      invalidNodeIds.value = extractInvalidNodeIds(validationResult.errors);
      useAlert(t('WORKFLOW.EDITOR.VALIDATION_FAILED'));
      return;
    }

    const payload = {
      name: trimmedName,
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
    invalidNodeIds.value = extractInvalidNodeIds(validationErrors.value);
    useAlert(t('WORKFLOW.EDITOR.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const workflowsListRoute = { name: 'workflows_list' };

const workflowNameInputId = 'workflow-editor-name';
const workflowActiveLabelId = 'workflow-editor-active-label';
const workflowActiveSwitchLabel = computed(() =>
  workflow.value.active
    ? t('WORKFLOW.EDITOR.ACTIVE_SWITCH_ON')
    : t('WORKFLOW.EDITOR.ACTIVE_SWITCH_OFF')
);

const activeStatusBadgeClass = computed(() =>
  workflow.value.active
    ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
    : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300'
);

const activeStatusLabel = computed(() =>
  workflow.value.active
    ? t('WORKFLOW.LIST.ACTIVE')
    : t('WORKFLOW.LIST.INACTIVE')
);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 h-full overflow-hidden bg-white dark:bg-slate-900">
    <header
      class="flex-shrink-0 z-10 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700"
    >
      <div
        class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3"
      >
        <div class="flex items-center gap-2 shrink-0">
          <BackButton
            compact
            :back-url="workflowsListRoute"
            :button-label="$t('WORKFLOW.EDITOR.BACK')"
          />
          <span
            class="hidden md:inline text-xs text-slate-500 dark:text-slate-400"
            translate="no"
          >
            {{ $t('WORKFLOW.EDITOR.BACK_TO_LIST') }}
          </span>
        </div>

        <div
          class="hidden sm:block w-px h-5 bg-slate-75 dark:bg-slate-700 shrink-0"
          aria-hidden="true"
        />

        <div class="flex flex-1 min-w-0 items-center gap-2 basis-full sm:basis-auto">
          <div class="flex flex-col min-w-0 flex-1 max-w-sm">
            <label :for="workflowNameInputId" class="sr-only">
              {{ $t('WORKFLOW.EDITOR.NAME_PLACEHOLDER') }}
            </label>
            <input
              :id="workflowNameInputId"
              v-model="workflow.name"
              name="workflow_name"
              type="text"
              autocomplete="off"
              spellcheck="false"
              :class="[
                'reset-base w-full m-0 h-auto px-3 py-1.5 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-200 bg-transparent border-0 placeholder:text-slate-400 dark:placeholder:text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700 focus-visible:outline-none focus-visible:bg-slate-50 dark:focus-visible:bg-slate-700 focus-visible:ring-2 transition-colors duration-200 ease-smooth',
                nameError
                  ? 'ring-2 ring-red-500 focus-visible:ring-red-500'
                  : 'focus-visible:ring-woot-500',
              ]"
              :placeholder="$t('WORKFLOW.EDITOR.NAME_PLACEHOLDER')"
              :aria-invalid="nameError"
              :aria-describedby="nameError ? 'workflow-name-error' : undefined"
              @input="markDirty"
            />
            <p
              v-if="nameError"
              id="workflow-name-error"
              class="mt-1 text-xs text-red-600 dark:text-red-400"
              role="alert"
            >
              {{ $t('WORKFLOW.EDITOR.NAME_REQUIRED') }}
            </p>
          </div>

          <span
            class="text-xs text-slate-400 dark:text-slate-500 whitespace-nowrap select-none"
            aria-live="polite"
            aria-atomic="true"
          >
            <template v-if="saveStatusIcon === 'saving'">
              <span class="flex items-center gap-1">
                <span
                  class="w-3 h-3 border border-woot-400 border-t-transparent rounded-full animate-spin workflow-editor-toolbar-spinner"
                  aria-hidden="true"
                />
                {{ saveStatusLabel }}
              </span>
            </template>
            <template v-else-if="saveStatusIcon === 'unsaved'">
              <span class="text-amber-500 dark:text-amber-400">{{ saveStatusLabel }}</span>
            </template>
            <template v-else>
              {{ saveStatusLabel }}
            </template>
          </span>
        </div>

        <div
          class="flex items-center gap-2 shrink-0 ml-auto"
          :class="{ 'pointer-events-none opacity-60': isSaving || isTogglingActive }"
          role="group"
          :aria-labelledby="workflowActiveLabelId"
        >
          <span
            :id="workflowActiveLabelId"
            class="text-xs font-medium text-slate-600 dark:text-slate-400 whitespace-nowrap hidden lg:inline"
          >
            {{ $t('WORKFLOW.EDITOR.WORKFLOW_ACTIVE') }}
          </span>
          <span
            class="hidden sm:inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium tabular-nums"
            :class="activeStatusBadgeClass"
          >
            {{ activeStatusLabel }}
          </span>
          <woot-switch
            :value="workflow.active"
            size="small"
            :aria-label="workflowActiveSwitchLabel"
            @input="onWorkflowActiveInput"
          />
        </div>

        <div
          class="hidden sm:block w-px h-5 bg-slate-75 dark:bg-slate-700 shrink-0"
          aria-hidden="true"
        />

        <div class="flex items-center gap-2 shrink-0">
          <woot-button
            v-tooltip="$t('WORKFLOW.EDITOR.FLOW_SETTINGS')"
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="settings"
            :aria-label="$t('WORKFLOW.EDITOR.FLOW_SETTINGS')"
            @click="openFlowSettings"
          />

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
            :disabled="saveAndActivateDisabled"
            @click="save(true)"
          >
            {{ $t('WORKFLOW.EDITOR.SAVE_AND_ACTIVATE') }}
          </woot-button>
        </div>
      </div>

      <div
        v-if="readOnlyGraph"
        class="flex items-center gap-2 px-4 py-2 text-xs bg-amber-50 dark:bg-amber-900/20 border-t border-amber-200 dark:border-amber-700/40 text-amber-800 dark:text-amber-300"
        role="status"
      >
        <fluent-icon icon="info" size="16" aria-hidden="true" />
        {{ $t('WORKFLOW.EDITOR.ACTIVE_READONLY') }}
      </div>
    </header>

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
        :invalid-node-ids="invalidNodeIds"
        @update:graph="onGraphUpdate"
        @node-selected="onNodeSelected"
      />
      <transition name="properties-panel">
        <WorkflowPropertiesPanel
          v-if="selectedNode"
          :key="selectedNode.id"
          :node="selectedNode"
          :read-only="readOnlyGraph"
          @update-node="onUpdateNode"
        />
      </transition>
    </div>

    <woot-modal
      :show.sync="showFlowSettings"
      :on-close="closeFlowSettings"
      :close-on-backdrop-click="true"
    >
      <div class="flex flex-col w-full max-w-md">
        <woot-modal-header
          :header-title="$t('WORKFLOW.EDITOR.FLOW_SETTINGS')"
          :header-content="$t('WORKFLOW.EDITOR.FLOW_SETTINGS_HINT')"
        />
        <div class="px-8 pb-8">
          <WorkflowFlowSettingsPanel
            :graph-settings="workflow.graph.settings"
            :read-only="readOnlyGraph"
            @update-settings="onUpdateSettings"
          />
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<style scoped>
.fade-down-enter-active,
.fade-down-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.fade-down-enter,
.fade-down-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}

/* Properties panel — fade + slide (same feel as animate-scale-in modals) */
.properties-panel-enter-active,
.properties-panel-leave-active {
  transition: opacity 0.2s ease-out, transform 0.2s ease-out;
}
.properties-panel-enter,
.properties-panel-leave-to {
  opacity: 0;
  transform: translateX(0.5rem) scale(0.98);
}
.properties-panel-enter-to,
.properties-panel-leave {
  opacity: 1;
  transform: translateX(0) scale(1);
}

@media (prefers-reduced-motion: reduce) {
  .fade-down-enter-active,
  .fade-down-leave-active,
  .properties-panel-enter-active,
  .properties-panel-leave-active {
    transition: none;
  }
  .workflow-editor-toolbar-spinner {
    animation: none;
    opacity: 0.7;
  }
}
</style>
