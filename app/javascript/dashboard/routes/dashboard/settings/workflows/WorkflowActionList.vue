<script setup>
import { ref, watch } from 'vue';
import draggable from 'vuedraggable';
import WorkflowActionFields from './WorkflowActionFields.vue';
import {
  defaultWorkflowAction,
  normalizeActionsList,
  syncActionNodeFields,
} from './workflowActionHelpers';

const props = defineProps({
  nodeId: { type: [String, Number], default: '' },
  nodeProps: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
  triggerEventName: { type: String, default: '' },
});

const emit = defineEmits(['update-node']);

const localActions = ref(normalizeActionsList(props.nodeProps));

// Remount/re-init when switching nodes only. Avoid deep-watching nodeProps
// (it was resetting local message drafts from stale nested actions[]).
watch(
  () => props.nodeId,
  () => {
    localActions.value = normalizeActionsList(props.nodeProps);
  }
);

const commit = list => {
  const payload = syncActionNodeFields(list);
  localActions.value = payload.actions;
  emit('update-node', payload);
};

const onDragEnd = () => {
  if (props.readOnly) return;
  commit([...localActions.value]);
};

const onUpdateAction = (index, action) => {
  if (props.readOnly) return;
  const next = localActions.value.map((item, i) =>
    i === index ? action : item
  );
  commit(next);
};

const addAction = () => {
  if (props.readOnly) return;
  commit([...localActions.value, defaultWorkflowAction()]);
};

const removeAction = index => {
  if (props.readOnly || localActions.value.length <= 1) return;
  commit(localActions.value.filter((_, i) => i !== index));
};
</script>

<template>
  <div class="workflow-action-list min-w-0">
    <draggable
      :list="localActions"
      handle=".workflow-action-drag-handle"
      tag="div"
      class="workflow-action-list__items"
      ghost-class="workflow-action-list__ghost"
      :animation="200"
      :disabled="readOnly || localActions.length <= 1"
      @end="onDragEnd"
    >
      <div
        v-for="(action, index) in localActions"
        :key="'action-' + index + '-' + action.action_name"
        class="workflow-action-list__node"
      >
        <div class="relative flex items-start w-full min-w-0 gap-2">
          <woot-button
            v-if="localActions.length > 1 && !readOnly"
            size="small"
            variant="clear"
            color-scheme="secondary"
            icon="navigation"
            class="workflow-action-drag-handle mt-3 shrink-0"
            :title="$t('WORKFLOW.EDITOR.ACTION_REORDER')"
            :aria-label="$t('WORKFLOW.EDITOR.ACTION_REORDER')"
          />
          <div
            class="flex-1 min-w-0 rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 p-3 shadow-soft"
          >
            <div
              class="mb-2 text-[11px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500"
            >
              {{ $t('WORKFLOW.EDITOR.ACTION_STEP', { index: index + 1 }) }}
            </div>
            <WorkflowActionFields
              :action="action"
              :read-only="readOnly"
              :trigger-event-name="triggerEventName"
              @update="onUpdateAction(index, $event)"
            />
          </div>
          <woot-button
            v-if="localActions.length > 1 && !readOnly"
            v-tooltip="$t('WORKFLOW.EDITOR.ACTION_REMOVE')"
            icon="delete"
            size="small"
            variant="smooth"
            color-scheme="alert"
            class="mt-3 shrink-0"
            :aria-label="$t('WORKFLOW.EDITOR.ACTION_REMOVE')"
            @click="removeAction(index)"
          />
        </div>
      </div>
    </draggable>

    <div v-if="!readOnly" class="pt-1">
      <woot-button
        color-scheme="success"
        variant="smooth"
        icon="add-circle"
        size="small"
        @click="addAction"
      >
        {{ $t('WORKFLOW.EDITOR.ACTION_ADD') }}
      </woot-button>
    </div>
  </div>
</template>

<style scoped lang="scss">
.workflow-action-list__node:not(:last-child) {
  position: relative;
  padding-bottom: 1.25rem;
}

.workflow-action-list__node:not(:last-child)::after {
  content: '';
  position: absolute;
  left: 1.15rem;
  bottom: 0;
  height: 1.25rem;
  border-left: 1px dashed var(--s-400, #94a3b8);
}

.workflow-action-list__ghost {
  opacity: 0.55;
}

.workflow-action-drag-handle {
  cursor: grab;
}

.workflow-action-drag-handle:active {
  cursor: grabbing;
}
</style>
