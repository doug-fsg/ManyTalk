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
import WorkflowValidationBanner from './WorkflowValidationBanner.vue';
import WorkflowSimulateModal from './WorkflowSimulateModal.vue';
import WorkflowNodeModalHeader from './WorkflowNodeModalHeader.vue';
import WorkflowActivateConfirmModal from './WorkflowActivateConfirmModal.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
import {
  emptyGraph,
  serializeGraphForApi,
  normalizeWorkflowGraph,
  extractInvalidNodeIds,
  normalizeValidationErrors,
} from 'dashboard/helper/workflowGraphHelper';
import { humanizeValidationError } from 'dashboard/helper/workflowValidationMessages';
import { ensureWorkflowEditorBootstrapped } from './useWorkflowEditorBootstrap';
import {
  FORM_SUBMITTED_EVENT_KEY,
  buildFormSubmittedConditions,
} from './workflowExtensions';
import {
  normalizeActionsList,
  syncActionNodeFields,
} from './workflowActionHelpers';

const WorkflowCanvas = defineAsyncComponent(() => import('./WorkflowCanvas.vue'));

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const workflow = ref({ name: '', description: '', active: false, graph: emptyGraph() });
/** Last `active` value persisted on the server (not draft toggle). */
const activeSaved = ref(false);
/** Node open in the edit modal (double-click). */
const editingNode = ref(null);
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
const showSimulate = ref(false);
const activateConfirmRef = ref(null);
const deactivateConfirmRef = ref(null);
const conflictingAutomations = ref([]);
const isTogglingActive = ref(false);

const workflowId = computed(() => route.params.workflowId);
const isEdit = computed(() => Boolean(workflowId.value));
const syncActiveState = isActive => {
  const active = Boolean(isActive);
  workflow.value.active = active;
  activeSaved.value = active;
};

const seedActiveFromStore = () => {
  if (!workflowId.value) return;
  const cached = store.getters['workflows/getWorkflow'](Number(workflowId.value));
  if (cached) syncActiveState(cached.active);
};

/** Flow is active on the server — diagram stays locked until deactivated. */
const isFlowActive = computed(
  () => isEdit.value && Boolean(activeSaved.value || workflow.value.active)
);
const readOnlyGraph = computed(() => isFlowActive.value);

const validationErrorsByNodeId = computed(() => {
  const map = {};
  validationErrors.value.forEach(err => {
    if (!err.node_id) return;
    if (!map[err.node_id]) map[err.node_id] = [];
    map[err.node_id].push(err.message);
  });
  return map;
});

const editingNodeErrors = computed(() => {
  if (!editingNode.value?.id) return [];
  const raw = validationErrorsByNodeId.value[editingNode.value.id] || [];
  return raw.map(message => humanizeValidationError(message, t));
});

const triggerEventName = computed(() => {
  const nodes = workflow.value?.graph?.nodes || [];
  const trigger = nodes.find(node => node.type === 'trigger');
  return trigger?.data?.event_name || '';
});

const NODE_TYPE_LABEL_KEYS = {
  trigger: 'WORKFLOW.EDITOR.NODE_TRIGGER',
  wait: 'WORKFLOW.EDITOR.NODE_WAIT',
  wait_for_reply: 'WORKFLOW.EDITOR.NODE_WAIT_FOR_REPLY',
  condition: 'WORKFLOW.EDITOR.NODE_CONDITION',
  action: 'WORKFLOW.EDITOR.NODE_ACTION',
  ai_outreach: 'WORKFLOW.EDITOR.NODE_CALL_CLIENT',
  ai_conversation_analysis: 'WORKFLOW.EDITOR.NODE_CONVERSATION_ANALYSIS',
  ai_wait_for_intent: 'WORKFLOW.EDITOR.NODE_AI_WAIT_FOR_INTENT',
};

const editingNodeTypeLabel = computed(() => {
  const type =
    editingNode.value &&
    editingNode.value.properties &&
    editingNode.value.properties.workflowNodeType;
  const key = NODE_TYPE_LABEL_KEYS[type];
  return key ? t(key) : t('WORKFLOW.EDITOR.NODE_SETTINGS');
});

/** Node types that need a taller/wider modal (lists, multi-action, long forms). */
const LARGE_NODE_MODAL_TYPES = [
  'action',
  'ai_outreach',
  'wait_for_reply',
];

const editingNodeModalSize = computed(() => {
  const type =
    editingNode.value &&
    editingNode.value.properties &&
    editingNode.value.properties.workflowNodeType;
  return LARGE_NODE_MODAL_TYPES.indexOf(type) !== -1 ? 'large' : 'medium';
});

const editingNodeModalShellClass = computed(() => {
  const type =
    editingNode.value &&
    editingNode.value.properties &&
    editingNode.value.properties.workflowNodeType;
  if (type === 'action') {
    return 'h-[40rem] max-h-[min(40rem,90vh)]';
  }
  if (LARGE_NODE_MODAL_TYPES.indexOf(type) !== -1) {
    return 'h-[34rem] max-h-[min(34rem,85vh)]';
  }
  // Compact nodes: trigger, wait, condition, AI analysis, wait-for-intent, etc.
  return 'h-[26rem] max-h-[min(26rem,80vh)]';
});

const onEditingNodeTitleUpdate = value => {
  onUpdateNode({ label: value });
};

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
    syncActiveState(false);
    return;
  }

  seedActiveFromStore();
  isLoading.value = true;
  loadError.value = null;
  try {
    const response = await WorkflowsAPI.show(workflowId.value);
    const data = response.data?.payload ?? response.data;
    const isActive = Boolean(data?.active);
    workflow.value = {
      ...data,
      active: isActive,
      graph: normalizeWorkflowGraph(data.graph || emptyGraph()),
    };
    conflictingAutomations.value = data?.conflicting_automations ?? [];
    syncActiveState(isActive);
    graphRevision.value += 1;
    isDirty.value = false;
    dismissValidationErrors();
  } catch {
    loadError.value = t('WORKFLOW.EDITOR.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const applyConnectFormSeedIfNeeded = async () => {
  if (isEdit.value) return;

  const connectFormId = route.query.connectFormId;
  if (!connectFormId) return;

  const forms = store.getters['accountForms/getAccountForms'] || [];
  const form = forms.find(record => String(record.id) === String(connectFormId));

  if (!form) return;

  if (form.status !== 'published') {
    useAlert(t('ACCOUNT_FORM.LIST.FLOW.CONNECT_DRAFT_WARNING'));
    router.replace({ query: {} });
    return;
  }

  const graph = workflow.value.graph;
  const trigger = (graph.nodes || []).find(node => node.type === 'trigger');
  if (!trigger) return;

  trigger.data = {
    ...(trigger.data || {}),
    event_name: FORM_SUBMITTED_EVENT_KEY,
    conditions: buildFormSubmittedConditions([connectFormId]),
  };

  graphRevision.value += 1;
  markDirty();

  await nextTick();
  await nextTick();
  canvasRef.value?.focusNode?.(trigger.id);

  useAlert(t('ACCOUNT_FORM.LIST.FLOW.CONNECT_INBOX_HINT'));
  router.replace({ query: {} });
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

onMounted(async () => {
  await ensureWorkflowEditorBootstrapped(store);
  seedActiveFromStore();
  await loadWorkflow();
  await applyConnectFormSeedIfNeeded();
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

const confirmActivation = async () =>
  activateConfirmRef.value?.showConfirmation({
    conflictingAutomations: conflictingAutomations.value,
  });

const persistActiveState = async value => {
  if (isTogglingActive.value || value === activeSaved.value) {
    workflow.value.active = value;
    return false;
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
    syncActiveState(updated.active);
    useAlert(t('WORKFLOW.TOGGLE.SUCCESS'));
    return true;
  } catch {
    workflow.value.active = previousActive;
    syncActiveState(previousActive);
    useAlert(t('WORKFLOW.TOGGLE.ERROR'));
    return false;
  } finally {
    isTogglingActive.value = false;
  }
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

  if (value && !(await confirmActivation())) {
    workflow.value.active = activeSaved.value;
    return;
  }

  await persistActiveState(value);
};

/** One-click path out of readonly: confirm → deactivate → canvas unlocks. */
const deactivateToEdit = async () => {
  if (!isFlowActive.value || isTogglingActive.value) return;
  const ok = await deactivateConfirmRef.value?.showConfirmation();
  if (!ok) return;
  await persistActiveState(false);
};

const onValidationFocusError = nodeId => {
  if (!nodeId || !canvasRef.value?.focusNode) return;
  canvasRef.value.focusNode(nodeId);
};
const onGraphUpdate = graph => {
  if (readOnlyGraph.value) return;
  workflow.value.graph = graph;
  markDirty();
};

const dismissValidationErrors = () => {
  validationErrors.value = [];
  invalidNodeIds.value = [];
};

const showValidationFailures = async errors => {
  validationErrors.value = normalizeValidationErrors(errors);
  invalidNodeIds.value = extractInvalidNodeIds(validationErrors.value);
  await nextTick();
  if (canvasRef.value?.focusFirstInvalidNode) {
    canvasRef.value.focusFirstInvalidNode(invalidNodeIds.value);
  }
};
const onNodeEdit = node => {
  if (!node) {
    editingNode.value = null;
    return;
  }
  const properties = node.properties || {};
  if (properties.workflowNodeType === 'action') {
    editingNode.value = {
      ...node,
      properties: {
        ...properties,
        ...syncActionNodeFields(normalizeActionsList(properties)),
      },
    };
    return;
  }
  editingNode.value = node;
};

const closeNodeEdit = () => {
  if (canvasRef.value && canvasRef.value.flushGraphChange) {
    canvasRef.value.flushGraphChange();
  }
  editingNode.value = null;
};

const onUpdateNode = props => {
  if (!editingNode.value?.id || !canvasRef.value?.updateNodeProperties) return;
  const merged = canvasRef.value.updateNodeProperties(editingNode.value.id, props);
  editingNode.value = {
    ...editingNode.value,
    properties: merged || { ...editingNode.value.properties, ...props },
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

const openSimulate = () => {
  showSimulate.value = true;
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

  const isActiveOnServer = isFlowActive.value;
  const canUpdateGraph = !isActiveOnServer;
  const canUpdateSettingsOnly = isActiveOnServer;

  if (activate && !isActiveOnServer && !(await confirmActivation())) {
    return;
  }

  isSaving.value = true;
  try {
    if (canUpdateGraph && canvasRef.value?.flushGraphSync) {
      canvasRef.value.flushGraphSync();
    }
    const rawGraph =
      canUpdateGraph && canvasRef.value?.getGraphForSave
        ? canvasRef.value.getGraphForSave()
        : workflow.value.graph;
    const graph = canUpdateGraph || canUpdateSettingsOnly
      ? serializeGraphForApi(rawGraph)
      : null;

    if (canUpdateGraph) {
      const validationResponse = await WorkflowsAPI.validate(graph);
      const validationResult = validationResponse.data || {};
      if (!validationResult.valid) {
        await showValidationFailures(validationResult.errors);
        return;
      }
    }

    const payload = {
      name: trimmedName,
      description: workflow.value.description,
    };
    if (activate) {
      payload.active = true;
    } else if (!isActiveOnServer) {
      payload.active = workflow.value.active;
    }
    if (canUpdateGraph || canUpdateSettingsOnly) {
      payload.graph = graph;
    }

    if (isEdit.value) {
      const updated = await store.dispatch('workflows/update', {
        id: workflowId.value,
        ...payload,
      });
      workflow.value = { ...workflow.value, ...updated };
      syncActiveState(updated.active);
    } else {
      payload.graph = graph;
      payload.active = activate ? true : workflow.value.active;
      const created = await store.dispatch('workflows/create', payload);
      workflow.value = { ...workflow.value, ...created };
      syncActiveState(created.active);
      router.replace({ name: 'workflows_edit', params: { workflowId: created.id } });
    }
    isDirty.value = false;
    dismissValidationErrors();
    useAlert(t('WORKFLOW.EDITOR.SAVE_SUCCESS'));
  } catch (e) {
    const err = e && e.response && e.response.data && e.response.data.error;
    const messages = Array.isArray(err) ? err : [err || t('WORKFLOW.EDITOR.SAVE_ERROR')];
    if (isActiveOnServer) {
      useAlert(humanizeValidationError(messages[0], t) || t('WORKFLOW.EDITOR.SAVE_ERROR'));
    } else {
      await showValidationFailures(messages);
      useAlert(t('WORKFLOW.EDITOR.SAVE_ERROR'));
    }
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
            v-if="isEdit"
            v-tooltip="$t('WORKFLOW.SIMULATE.TOOLTIP')"
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="play-circle"
            :aria-label="$t('WORKFLOW.SIMULATE.TOOLTIP')"
            @click="openSimulate"
          />

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
            v-if="!isFlowActive"
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
    </header>

    <div
      v-if="isFlowActive"
      class="flex-shrink-0 flex flex-wrap items-center gap-x-3 gap-y-1.5 px-4 py-2 text-xs border-b border-amber-200/70 dark:border-amber-800/40 bg-amber-50/70 dark:bg-amber-950/25 text-amber-900/90 dark:text-amber-200/90"
      role="status"
    >
      <span class="flex items-center gap-1.5 min-w-0 flex-1">
        <fluent-icon
          icon="info"
          size="14"
          class="text-amber-600 dark:text-amber-400 flex-shrink-0"
          aria-hidden="true"
        />
        <span class="min-w-0">
          <span class="font-medium">{{ $t('WORKFLOW.EDITOR.ACTIVE_READONLY') }}</span>
          <span class="text-amber-700/80 dark:text-amber-300/80">
            {{ ' ' }}{{ $t('WORKFLOW.EDITOR.ACTIVE_SETTINGS_HINT') }}
          </span>
        </span>
      </span>
      <woot-button
        size="tiny"
        color-scheme="warning"
        variant="smooth"
        :is-loading="isTogglingActive"
        class="shrink-0"
        @click="deactivateToEdit"
      >
        {{ $t('WORKFLOW.EDITOR.DEACTIVATE_TO_EDIT') }}
      </woot-button>
    </div>

    <WorkflowValidationBanner
      v-if="validationErrors.length"
      :errors="validationErrors"
      @dismiss="dismissValidationErrors"
      @focus-error="onValidationFocusError"
    />

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
        @node-edit="onNodeEdit"
      />
    </div>

    <woot-modal
      :show="Boolean(editingNode)"
      :on-close="closeNodeEdit"
      :close-on-backdrop-click="true"
      :size="editingNodeModalSize"
    >
      <div
        v-if="editingNode"
        class="flex flex-col w-full overscroll-contain"
        :class="editingNodeModalShellClass"
      >
        <WorkflowNodeModalHeader
          :title="
            (editingNode.properties && editingNode.properties.label) || ''
          "
          :placeholder="editingNodeTypeLabel"
          :hint="$t('WORKFLOW.EDITOR.NODE_SETTINGS_HINT')"
          :read-only="readOnlyGraph"
          @update:title="onEditingNodeTitleUpdate"
        />
        <div class="flex-1 min-h-0 px-8 overflow-y-auto overscroll-contain">
          <WorkflowPropertiesPanel
            :key="editingNode.id"
            :node="editingNode"
            :read-only="readOnlyGraph"
            :node-errors="editingNodeErrors"
            :trigger-event-name="triggerEventName"
            as-modal
            @update-node="onUpdateNode"
          />
        </div>
        <div
          class="flex shrink-0 justify-end px-8 py-4 border-t border-slate-75 dark:border-slate-700/50"
        >
          <woot-button size="small" @click="closeNodeEdit">
            {{ $t('WORKFLOW.EDITOR.FLOW_SETTINGS_DONE') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <woot-modal
      :show.sync="showFlowSettings"
      :on-close="closeFlowSettings"
      :close-on-backdrop-click="true"
      size="medium"
    >
      <div
        class="flex flex-col w-full h-[32rem] max-h-[min(32rem,80vh)]"
      >
        <woot-modal-header
          :header-title="$t('WORKFLOW.EDITOR.FLOW_SETTINGS')"
          :header-content="$t('WORKFLOW.EDITOR.FLOW_SETTINGS_HINT')"
        />
        <div class="flex-1 min-h-0 px-8 overflow-hidden">
          <WorkflowFlowSettingsPanel
            :graph-settings="workflow.graph.settings"
            :read-only="false"
            @update-settings="onUpdateSettings"
          />
        </div>
        <div
          class="flex shrink-0 justify-end px-8 py-4 border-t border-slate-75 dark:border-slate-700/50"
        >
          <woot-button size="small" @click="closeFlowSettings">
            {{ $t('WORKFLOW.EDITOR.FLOW_SETTINGS_DONE') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <WorkflowSimulateModal
      v-if="isEdit && workflowId"
      :show="showSimulate"
      :workflow-id="workflowId"
      @close="showSimulate = false"
    />

    <WorkflowActivateConfirmModal ref="activateConfirmRef" />

    <ConfirmationModal
      ref="deactivateConfirmRef"
      :title="$t('WORKFLOW.EDITOR.DEACTIVATE_TO_EDIT_TITLE')"
      :description="$t('WORKFLOW.EDITOR.DEACTIVATE_TO_EDIT_DESC')"
      :confirm-label="$t('WORKFLOW.EDITOR.DEACTIVATE_TO_EDIT')"
      :cancel-label="$t('WORKFLOW.ACTIVATE_MODAL.CANCEL')"
    />
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

@media (prefers-reduced-motion: reduce) {
  .fade-down-enter-active,
  .fade-down-leave-active {
    transition: none;
  }
  .workflow-editor-toolbar-spinner {
    animation: none;
    opacity: 0.7;
  }
}
</style>
