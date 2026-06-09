<template>
  <div class="relative" :class="{ group: hasActiveEnrollment }">
    <woot-button
      v-tooltip="tooltipText"
      variant="clear"
      color-scheme="secondary"
      class="regua-trigger"
      :aria-label="ariaLabel"
      @click="openPopup"
    >
      <fluent-icon
        :icon="statusIcon"
        size="19"
        :class="iconClass"
        aria-hidden="true"
      />
      <span
        v-if="buttonLabel"
        class="text-xs font-medium max-w-[8rem] truncate text-ash-800 dark:text-ash-100"
      >
        {{ buttonLabel }}
      </span>
    </woot-button>

    <regua-status-popover
      v-if="hasActiveEnrollment && enrollment"
      :status="enrollment.status"
      :workflow-name="enrollment.workflow_name"
      :current-node-label="enrollment.current_node_label"
      :next-scheduled-at="enrollment.next_scheduled_at"
      :reply-watch="enrollment.reply_watch"
      class="right-0 top-[40px] invisible group-hover:visible"
    />

    <woot-modal
      :show.sync="shouldShowPopup"
      :on-close="closePopup"
      :close-on-backdrop-click="false"
    >
      <div class="flex flex-col h-auto overflow-auto w-full overscroll-contain">
        <woot-modal-header
          :header-title="$t('WORKFLOW.REGUA.TITLE')"
          :header-content="modalDescription"
        />
        <div class="flex flex-col px-8 pb-8">
          <ReguaPanel
            :conversation-id="conversationId"
            @updated="fetchActive"
          />
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<script setup>
import { computed, ref, toRef, watch, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useWorkflowEnrollment } from 'dashboard/composables/useWorkflowEnrollment';
import ReguaPanel from './ReguaPanel.vue';
import ReguaStatusPopover from './ReguaStatusPopover.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const conversationIdRef = toRef(props, 'conversationId');
const { enrollment, fetchActive } = useWorkflowEnrollment(conversationIdRef);

const shouldShowPopup = ref(false);

const hasActiveEnrollment = computed(() => !!enrollment.value?.id);

const STATUS_ICON = {
  idle: 'automation',
  active: 'play-circle',
  waiting: 'clock',
  paused: 'microphone-pause',
};

const STATUS_ICON_CLASS = {
  idle: 'text-slate-500 dark:text-slate-400',
  active: 'text-green-600 dark:text-green-400',
  waiting: 'text-violet-600 dark:text-violet-400',
  paused: 'text-amber-600 dark:text-amber-400',
};

const statusKey = computed(() => {
  if (!enrollment.value) return 'idle';
  return enrollment.value.status || 'active';
});

const statusIcon = computed(() => STATUS_ICON[statusKey.value] || STATUS_ICON.idle);

const iconClass = computed(
  () => STATUS_ICON_CLASS[statusKey.value] || STATUS_ICON_CLASS.idle
);

const statusLabel = computed(() => {
  if (!enrollment.value?.status) return null;
  return t(`WORKFLOW.REGUA.STATUS_${enrollment.value.status.toUpperCase()}`);
});

const buttonLabel = computed(() => {
  if (!enrollment.value) return null;
  return enrollment.value.current_node_label || statusLabel.value;
});

const tooltipText = computed(() => {
  if (!hasActiveEnrollment.value) return t('WORKFLOW.REGUA.TOOLTIP');
  return `${t('WORKFLOW.REGUA.TITLE')} — ${statusLabel.value}`;
});

const ariaLabel = computed(() => tooltipText.value);

const modalDescription = computed(() => {
  if (!hasActiveEnrollment.value) return t('WORKFLOW.REGUA.MODAL_EMPTY');
  return t('WORKFLOW.REGUA.MODAL_ACTIVE');
});

const openPopup = () => {
  shouldShowPopup.value = true;
};

const closePopup = () => {
  shouldShowPopup.value = false;
  fetchActive();
};

watch(
  () => props.conversationId,
  () => {
    fetchActive();
  }
);

onMounted(() => {
  fetchActive();
  pollTimer = window.setInterval(fetchActive, 30_000);
});

onUnmounted(() => {
  if (pollTimer) window.clearInterval(pollTimer);
});

let pollTimer = null;
</script>

<style scoped lang="scss">
.regua-trigger {
  ::v-deep .button__content {
    @apply gap-1.5;
  }
}
</style>
