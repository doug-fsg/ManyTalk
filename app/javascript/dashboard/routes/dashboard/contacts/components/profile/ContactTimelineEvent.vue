<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useRouter } from 'dashboard/composables/route';
import { useStore } from 'dashboard/composables/store';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import ContactNote from 'dashboard/modules/notes/components/ContactNote.vue';
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
});

const emit = defineEmits(['open-activities', 'refresh']);

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const isNote = computed(() => props.event.type === 'note');

const readableTime = computed(() => {
  const timestamp = Math.floor(
    new Date(props.event.occurred_at).getTime() / 1000
  );
  return messageTimestamp(timestamp, 'LLL d, h:mm a');
});

const noteUser = computed(() => ({
  name:
    props.event.meta?.user_name || t('CONTACT_PROFILE.TIMELINE.UNKNOWN_USER'),
}));

const noteCreatedAt = computed(() =>
  Math.floor(new Date(props.event.occurred_at).getTime() / 1000)
);

const title = computed(() => {
  const meta = props.event.meta || {};

  switch (props.event.type) {
    case 'contact_created':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.CONTACT_CREATED');
    case 'form_submission':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.FORM_SUBMISSION', {
        form:
          meta.account_form_name || t('CONTACT_PROFILE.TIMELINE.UNKNOWN_FORM'),
      });
    case 'pipeline_entered':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_ENTERED', {
        pipeline: meta.pipeline_name,
      });
    case 'pipeline_stage_changed':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_STAGE_CHANGED', {
        from: meta.from_stage_id,
        to: meta.to_stage_id || meta.stage_id,
        pipeline: meta.pipeline_name,
      });
    case 'pipeline_reopened':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_REOPENED', {
        pipeline: meta.pipeline_name,
      });
    case 'pipeline_stage':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.PIPELINE_STAGE', {
        stage: meta.stage_id,
        pipeline: meta.pipeline_name,
      });
    case 'deal_won':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.DEAL_WON', {
        pipeline: meta.pipeline_name,
      });
    case 'deal_lost':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.DEAL_LOST', {
        pipeline: meta.pipeline_name,
      });
    case 'activity':
      if (meta.timeline_moment === 'completed') {
        return t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY_COMPLETED', {
          title: meta.title || t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY'),
        });
      }
      return meta.title || t('CONTACT_PROFILE.TIMELINE.EVENTS.ACTIVITY');
    case 'conversation_started':
      return t('CONTACT_PROFILE.TIMELINE.EVENTS.CONVERSATION', {
        inbox: meta.inbox_name || t('CONTACT_PROFILE.TIMELINE.UNKNOWN_INBOX'),
      });
    default:
      return props.event.type;
  }
});

const suffixParts = computed(() => {
  const meta = props.event.meta || {};
  const parts = [];

  if (meta.assignee_name && !meta.user_name) {
    parts.push(
      t('CONTACT_PROFILE.TIMELINE.ASSIGNEE', { name: meta.assignee_name })
    );
  }

  if (props.event.type === 'form_submission' && meta.utm?.source) {
    parts.push(
      t('CONTACT_PROFILE.TIMELINE.UTM_SOURCE', { source: meta.utm.source })
    );
  }

  if (
    (props.event.type === 'deal_won' || props.event.type === 'deal_lost') &&
    meta.win_lost_notes
  ) {
    parts.push(meta.win_lost_notes);
  }

  if (props.event.type === 'pipeline_reopened' && meta.previous_status) {
    parts.push(
      t('CONTACT_PROFILE.TIMELINE.REOPENED_FROM', {
        status: meta.previous_status,
      })
    );
  }

  if (props.event.type === 'activity' && meta.description) {
    parts.push(meta.description);
  }

  if (props.event.type === 'activity' && meta.status) {
    if (meta.timeline_moment !== 'completed') {
      parts.push(t(`ACTIVITIES.STATUS.${meta.status.toUpperCase()}`));
    }
  }

  if (props.event.type === 'activity' && meta.timeline_moment === 'completed' && meta.scheduled_at) {
    const scheduledDate = new Date(meta.scheduled_at);
    parts.push(
      t('CONTACT_PROFILE.TIMELINE.SCHEDULED_FOR', {
        date: scheduledDate.toLocaleString('pt-BR', {
          day: '2-digit',
          month: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
        }),
      })
    );
  }

  return parts.filter(Boolean);
});

const auditLine = computed(() => {
  const meta = props.event.meta || {};
  const segments = [title.value];

  if (suffixParts.value.length) {
    segments.push(suffixParts.value.join(' · '));
  }

  let line = segments.join(' · ');

  if (meta.user_name) {
    line = `${line} ${t('CONTACT_PROFILE.TIMELINE.BY_USER', {
      name: meta.user_name,
    })}`;
  }

  return line;
});

const isClickable = computed(() => {
  if (props.event.type === 'activity') return true;
  if (props.event.type === 'conversation_started') return true;
  if (props.event.type === 'form_submission') return true;
  return [
    'pipeline_entered',
    'pipeline_stage_changed',
    'pipeline_reopened',
    'deal_won',
    'deal_lost',
  ].includes(props.event.type);
});

const onAuditClick = () => {
  const meta = props.event.meta || {};

  if (props.event.type === 'activity') {
    emit('open-activities', meta.activity_id);
    return;
  }

  if (props.event.type === 'conversation_started') {
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

const onDeleteNote = async noteId => {
  await store.dispatch('contactNotes/delete', {
    noteId,
    contactId: props.contactId,
  });
  emit('refresh');
};
</script>

<template>
  <div class="contact-timeline-event">
    <contact-note
      v-if="isNote"
      :id="event.meta.note_id"
      :note="event.meta.content"
      :user="noteUser"
      :created-at="noteCreatedAt"
      @delete="onDeleteNote"
    />

    <div
      v-else
      class="timeline-audit"
      :class="{ 'timeline-audit--clickable': isClickable }"
      role="listitem"
      @click="isClickable ? onAuditClick() : null"
    >
      <div class="timeline-audit__bubble">
        <span class="timeline-audit__text">{{ auditLine }}</span>
        <span class="timeline-audit__time">{{ readableTime }}</span>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.timeline-audit {
  @apply my-1 flex justify-center;

  &--clickable {
    @apply cursor-pointer;
  }

  &__bubble {
    @apply inline-flex max-w-full items-center gap-2 rounded-md border border-solid border-slate-100 bg-slate-50 py-1 pl-2.5 pr-2 text-sm text-slate-800 dark:border-slate-600 dark:bg-slate-600 dark:text-slate-100;
  }

  &__text {
    @apply min-w-0 text-left;
  }

  &__time {
    @apply shrink-0 whitespace-nowrap text-xxs text-slate-300 dark:text-slate-200;
  }
}
</style>
