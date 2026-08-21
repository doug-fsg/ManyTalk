<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useRouter } from 'dashboard/composables/route';
import { useStore } from 'dashboard/composables/store';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import {
  EVENT_TONE_CLASSES,
  formatTimelineAbsoluteTime,
  formatTimelineRelativeTime,
  getEventPresentation,
  getEventUnixTime,
} from '../../helpers/contactTimelineHelper';
import { buildContactsByFormRoute } from '../../utils/contactsNavigationHelper';
import { buildKanbanDeepLink } from '../../../crm/utils/crmNavigationHelper';

const props = defineProps({
  event: {
    type: Object,
    required: true,
  },
  accountId: {
    type: [String, Number],
    required: true,
  },
  contactId: {
    type: [String, Number],
    required: true,
  },
  isLast: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['open-activities', 'refresh', 'open-notes']);

const { t, locale } = useI18n();
const router = useRouter();
const store = useStore();

const presentation = computed(() =>
  getEventPresentation(props.event, t, locale.value)
);

const relativeTime = computed(() =>
  formatTimelineRelativeTime(getEventUnixTime(props.event), locale.value)
);

const absoluteTime = computed(() =>
  formatTimelineAbsoluteTime(getEventUnixTime(props.event), locale.value)
);

const iconToneClass = computed(
  () => EVENT_TONE_CLASSES[presentation.value.tone] || EVENT_TONE_CLASSES.neutral
);

const isInteractive = computed(
  () => presentation.value.isClickable || props.event.type === 'note'
);

const canDeleteNote = computed(
  () => props.event.type === 'note' && props.event.meta && props.event.meta.note_id
);

const contextLineKey = index => `${props.event.id}-context-${index}`;

const onItemClick = () => {
  if (!presentation.value.isClickable) {
    if (props.event.type === 'note') {
      emit('open-notes');
    }
    return;
  }

  const meta = props.event.meta || {};

  if (props.event.type === 'activity') {
    emit('open-activities', meta.activity_id);
    return;
  }

  if (
    props.event.type === 'conversation_started' ||
    props.event.type === 'workflow_started' ||
    props.event.type === 'workflow_cancelled' ||
    props.event.type === 'workflow_completed' ||
    props.event.type === 'workflow_failed'
  ) {
    const conversationId =
      meta.conversation_internal_id || meta.conversation_id;
    if (!conversationId) return;
    router.push(
      `/app/accounts/${props.accountId}/conversations/${conversationId}`
    );
    return;
  }

  if (props.event.type === 'form_submission' && meta.account_form_id) {
    router.push(
      buildContactsByFormRoute(props.accountId, meta.account_form_id)
    );
    return;
  }

  if (meta.pipeline_id) {
    router.push(
      buildKanbanDeepLink(props.accountId, {
        pipelineId: meta.pipeline_id,
      })
    );
  }
};

const onDeleteNote = async () => {
  const noteId = props.event.meta?.note_id;
  if (!noteId) return;

  await store.dispatch('contactNotes/delete', {
    noteId,
    contactId: props.contactId,
  });
  emit('refresh');
};
</script>

<template>
  <li class="relative flex gap-3 pb-1">
    <div class="flex flex-col items-center pt-0.5">
      <span
        class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full"
        :class="iconToneClass"
      >
        <FluentIcon :icon="presentation.icon" size="14" />
      </span>
      <span
        v-if="!isLast"
        class="mt-1 w-px min-h-[1rem] flex-1 bg-slate-200 dark:bg-slate-600"
      />
    </div>

    <div class="min-w-0 flex-1 pb-4">
      <button
        v-if="isInteractive"
        type="button"
        class="group w-full rounded-lg border border-transparent px-2 py-2 text-left transition-colors duration-150 cursor-pointer hover:border-slate-200 hover:bg-white dark:hover:border-slate-700 dark:hover:bg-slate-900"
        @click="onItemClick"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
              {{ presentation.title }}
            </p>

            <p
              v-for="(line, index) in presentation.contextLines"
              :key="contextLineKey(index)"
              class="mt-0.5 text-xs leading-relaxed text-slate-500 dark:text-slate-400"
            >
              {{ line }}
            </p>

            <div class="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
              <span
                v-tooltip.top="absoluteTime"
                class="text-xs tabular-nums text-slate-400 dark:text-slate-500"
              >
                {{ relativeTime }}
              </span>

              <span
                v-if="presentation.actionLabel"
                class="inline-flex items-center gap-0.5 text-xs font-medium text-woot-600 opacity-0 transition-opacity duration-150 group-hover:opacity-100 dark:text-woot-400"
              >
                {{ presentation.actionLabel }}
                <FluentIcon icon="arrow-chevron-right" size="12" />
              </span>
            </div>
          </div>

          <button
            v-if="canDeleteNote"
            v-tooltip="$t('NOTES.CONTENT_HEADER.DELETE')"
            type="button"
            class="shrink-0 rounded-md p-1 text-slate-400 opacity-0 transition-all duration-150 hover:bg-slate-100 hover:text-slate-600 group-hover:opacity-100 dark:hover:bg-slate-800 dark:hover:text-slate-200"
            @click.stop="onDeleteNote"
          >
            <FluentIcon icon="delete" size="14" />
          </button>
        </div>
      </button>

      <div
        v-else
        class="group w-full rounded-lg border border-transparent px-2 py-2 text-left"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
              {{ presentation.title }}
            </p>

            <p
              v-for="(line, index) in presentation.contextLines"
              :key="contextLineKey(index)"
              class="mt-0.5 text-xs leading-relaxed text-slate-500 dark:text-slate-400"
            >
              {{ line }}
            </p>

            <div class="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
              <span
                v-tooltip.top="absoluteTime"
                class="text-xs tabular-nums text-slate-400 dark:text-slate-500"
              >
                {{ relativeTime }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </li>
</template>
