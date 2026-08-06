<template>
  <div class="flex flex-col">
    <div
      v-if="isLoading"
      class="text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('WORKFLOW.REGUA.LOADING') }}
    </div>
    <template v-else-if="enrollment">
      <ReguaPanelStatus
        :status="enrollment.status"
        :workflow-name="enrollment.workflow_name"
        :current-node-label="enrollment.current_node_label"
        :current-node-type="enrollment.current_node_type"
        :next-scheduled-at="enrollment.next_scheduled_at"
        :reply-watch="enrollment.reply_watch"
      />
      <ReguaTimeline
        v-if="enrollment.timeline && enrollment.timeline.length"
        class="mt-4"
        :timeline="enrollment.timeline"
        :current-node-id="enrollment.current_node_id"
      />
      <ReguaRebindSelect
        v-if="contactConversations.length > 1"
        v-model="rebindConversationId"
        class="mt-4"
        :conversations="contactConversations"
        :current-conversation-id="Number(conversationId)"
        :is-rebinding="actionLoading === 'rebind'"
        @rebind="onRebind"
      />
      <ReguaPanelActions
        class="mt-4"
        :is-paused="enrollment.status === 'paused'"
        :is-pausing="actionLoading === 'pause'"
        :is-resuming="actionLoading === 'resume'"
        :is-cancelling="actionLoading === 'cancel'"
        :is-jumping="actionLoading === 'jump'"
        :available-stages="enrollment.available_stages || []"
        @pause="onPause"
        @resume="onResume"
        @cancel="onCancel"
        @jump="onJump"
      />
    </template>
    <ReguaPanelStartForm
      v-else
      :workflows="activeWorkflows"
      :is-loading="isFetchingWorkflows"
      :is-starting="actionLoading === 'start'"
      @start="onStart"
    />
  </div>
</template>

<script setup>
import { ref, computed, toRef, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { useWorkflowEnrollment } from 'dashboard/composables/useWorkflowEnrollment';
import { useWorkflowEnrollmentChannel } from 'dashboard/composables/useWorkflowEnrollmentChannel';
import ReguaPanelStatus from './ReguaPanelStatus.vue';
import ReguaPanelActions from './ReguaPanelActions.vue';
import ReguaPanelStartForm from './ReguaPanelStartForm.vue';
import ReguaTimeline from './ReguaTimeline.vue';
import ReguaRebindSelect from './ReguaRebindSelect.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const emit = defineEmits(['updated', 'active-change']);

const store = useStore();
const { t } = useI18n();

const conversationIdRef = toRef(props, 'conversationId');
const { enrollment, isLoading, fetchActive, start, pause, resume, cancel, jump, rebind } =
  useWorkflowEnrollment(conversationIdRef);

const actionLoading = ref(null);
const isFetchingWorkflows = ref(false);
const rebindConversationId = ref(Number(props.conversationId));

useWorkflowEnrollmentChannel({
  onUpdate: payload => {
    if (Number(payload.conversation_id) === Number(props.conversationId)) {
      fetchActive();
    }
    emit('updated');
  },
});

onMounted(async () => {
  isFetchingWorkflows.value = true;
  try {
    await store.dispatch('workflows/get');
  } finally {
    isFetchingWorkflows.value = false;
  }
});

const activeWorkflows = computed(() => {
  const workflows = store.getters['workflows/getWorkflows'] || [];
  return workflows.filter(w => w.active);
});

const currentChat = computed(() =>
  store.getters.getSelectedChat?.id === Number(props.conversationId)
    ? store.getters.getSelectedChat
    : null
);

const contactConversations = computed(() => {
  const chat = currentChat.value;
  if (!chat?.meta?.sender?.id) return [];

  const all = store.getters.getAllConversations || [];
  return all
    .filter(
      c =>
        c.meta?.sender?.id === chat.meta.sender.id &&
        c.status === 'open'
    )
    .map(c => ({
      id: c.id,
      inbox_id: c.inbox_id,
      label: `${c.inbox?.name || t('WORKFLOW.REGUA.INBOX_FALLBACK')} #${c.id}`,
    }));
});

const withLoading = async (action, fn) => {
  actionLoading.value = action;
  try {
    const result = await fn();
    if (result?.success) {
      const key = action === 'rebind' ? 'REBIND' : action.toUpperCase();
      useAlert(t(`WORKFLOW.REGUA.${key}_SUCCESS`));
      emit('updated');
    } else if (result?.error) {
      const status = result.error?.response?.status;
      if (status === 409) {
        useAlert(t('WORKFLOW.REGUA.ERROR_CONFLICT'));
      } else if (status === 403) {
        useAlert(t('WORKFLOW.REGUA.ERROR_FORBIDDEN'));
      } else {
        useAlert(t('WORKFLOW.REGUA.ERROR_GENERIC'));
      }
    }
  } finally {
    actionLoading.value = null;
  }
};

const onStart = workflowId => withLoading('start', () => start(workflowId));
const onPause = () => withLoading('pause', () => pause());
const onResume = () => withLoading('resume', () => resume());
const onCancel = () => withLoading('cancel', () => cancel());
const onJump = nodeId => withLoading('jump', () => jump(nodeId));
const onRebind = conversationId =>
  withLoading('rebind', () => rebind(conversationId));

watch(
  enrollment,
  value => {
    emit('active-change', !!value?.id);
  },
  { immediate: true }
);
</script>
