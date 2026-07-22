<template>
  <div class="activity-detail flex flex-col max-h-[85vh]">
    <div class="flex-shrink-0 px-6 pt-6 pb-4 border-b border-slate-200 dark:border-slate-700">
      <div class="flex items-start gap-3">
        <div
          :class="[
            'flex-shrink-0 w-11 h-11 rounded-xl flex items-center justify-center',
            typeIconBgClass,
          ]"
        >
          <fluent-icon :icon="typeIcon" size="22" :class="typeIconColorClass" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between gap-3">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-white leading-snug">
              {{ activity.title }}
            </h2>
            <span :class="['flex-shrink-0 px-2.5 py-0.5 rounded-full text-xs font-medium', statusBadgeClass]">
              {{ statusLabel }}
            </span>
          </div>
          <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
            {{ typeLabel }}
          </p>
        </div>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto px-6 py-4 space-y-5">
      <div
        v-if="activity.status === 'failed'"
        class="px-3 py-2.5 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800"
      >
        <p class="text-xs font-medium text-red-800 dark:text-red-200">
          {{ $t('ACTIVITIES.DETAIL.FAILURE_TITLE') }}
        </p>
        <p v-if="failureReason" class="text-xs text-red-700 dark:text-red-300 mt-1">
          {{ failureReason }}
        </p>
      </div>

      <section class="space-y-3">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.DETAIL.SCHEDULE') }}
        </h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <detail-row icon="calendar-clock" :label="$t('ACTIVITIES.FORM.SCHEDULED_AT')" :value="formattedScheduledAt" />
          <detail-row icon="clock" :label="$t('ACTIVITIES.DETAIL.CREATED_AT')" :value="formattedCreatedAt" />
          <detail-row
            v-if="activity.completed_at"
            icon="checkmark-circle"
            :label="$t('ACTIVITIES.DETAIL.COMPLETED_AT')"
            :value="formattedCompletedAt"
          />
        </div>
      </section>

      <section v-if="hasPeopleSection" class="space-y-3">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.DETAIL.PEOPLE') }}
        </h3>
        <div class="space-y-2">
          <detail-row
            v-if="activity.assignee"
            icon="person"
            :label="$t('ACTIVITIES.FORM.ASSIGNEE')"
            :value="activity.assignee.available_name || activity.assignee.name"
          />
          <detail-row
            v-if="activity.user"
            icon="person-add"
            :label="$t('ACTIVITIES.DETAIL.CREATED_BY')"
            :value="activity.user.available_name || activity.user.name"
          />
        </div>
      </section>

      <section v-if="activity.pipeline" class="space-y-3">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.DETAIL.PIPELINE') }}
        </h3>
        <div class="flex items-center justify-between gap-3 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700">
          <div class="flex items-center gap-3 min-w-0">
            <div class="flex items-center justify-center w-9 h-9 rounded-lg bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 flex-shrink-0">
              <fluent-icon icon="kanban" size="18" />
            </div>
            <div class="min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                {{ activity.pipeline.name }}
              </p>
              <p v-if="pipelineStageLabel" class="text-xs text-slate-500 dark:text-slate-400 truncate">
                {{ pipelineStageLabel }}
              </p>
            </div>
          </div>
          <router-link
            v-if="pipelineKanbanLink"
            :to="pipelineKanbanLink"
            class="text-xs font-medium text-woot-500 hover:text-woot-600 dark:text-woot-400 whitespace-nowrap flex-shrink-0"
          >
            {{ $t('ACTIVITIES.DETAIL.OPEN_IN_PIPELINE') }}
          </router-link>
        </div>
      </section>

      <section v-if="activity.inbox" class="space-y-3">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.DETAIL.CHANNEL') }}
        </h3>
        <detail-row icon="send-clock" :label="$t('ACTIVITIES.FORM.INBOX')" :value="inboxLabel" />
      </section>

      <section v-if="activity.description" class="space-y-2">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.FORM.DESCRIPTION') }}
        </h3>
        <p class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap leading-relaxed">
          {{ activity.description }}
        </p>
      </section>

      <section v-if="messagePreview" class="space-y-2">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.FORM.MESSAGE_CONTENT') }}
        </h3>
        <div class="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700">
          <p class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap leading-relaxed">
            {{ messagePreview }}
          </p>
        </div>
        <p v-if="whatsappTemplateName" class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('ACTIVITIES.DETAIL.WHATSAPP_TEMPLATE', { name: whatsappTemplateName }) }}
        </p>
      </section>

      <section v-if="activity.conversation" class="space-y-2">
        <router-link
          :to="conversationUrl"
          class="inline-flex items-center gap-1.5 text-sm font-medium text-woot-500 hover:text-woot-600 dark:text-woot-400"
        >
          <fluent-icon icon="chat" size="14" />
          {{ $t('ACTIVITIES.DETAIL.VIEW_CONVERSATION', { id: activity.conversation.display_id }) }}
        </router-link>
      </section>
    </div>

    <div class="flex-shrink-0 px-6 py-4 border-t border-slate-200 dark:border-slate-700 flex flex-wrap items-center justify-between gap-2">
      <div class="flex items-center gap-2">
        <woot-button
          v-if="canDelete"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          @click="$emit('delete', activity.id)"
        >
          {{ $t('ACTIVITIES.ACTIONS.DELETE') }}
        </woot-button>
      </div>
      <div class="flex items-center gap-2 ml-auto">
        <woot-button
          v-if="canComplete"
          color-scheme="success"
          icon="checkmark"
          @click="$emit('complete', activity.id)"
        >
          {{ $t('ACTIVITIES.ACTIONS.COMPLETE') }}
        </woot-button>
        <woot-button variant="smooth" icon="edit" @click="$emit('edit', activity)">
          {{ $t('ACTIVITIES.ACTIONS.EDIT') }}
        </woot-button>
      </div>
    </div>
  </div>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import { format, parseISO, isPast } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import DetailRow from './ActivityDetailRow.vue';
import { buildKanbanDeepLink } from '../../crm/utils/crmNavigationHelper';

const FAILURE_REASON_KEYS = {
  outside_messaging_window: 'ACTIVITIES.DETAIL.FAILURE_OUTSIDE_WINDOW',
  template_required: 'ACTIVITIES.DETAIL.FAILURE_TEMPLATE_REQUIRED',
  template_not_found: 'ACTIVITIES.DETAIL.FAILURE_TEMPLATE_NOT_FOUND',
  conversation_not_found: 'ACTIVITIES.DETAIL.FAILURE_CONVERSATION',
  message_content_required: 'ACTIVITIES.DETAIL.FAILURE_MESSAGE_REQUIRED',
  send_error: 'ACTIVITIES.DETAIL.FAILURE_SEND_ERROR',
};

export default {
  name: 'ActivityDetailModal',
  components: {
    FluentIcon,
    DetailRow,
  },
  props: {
    activity: {
      type: Object,
      required: true,
    },
    accountId: {
      type: [Number, String],
      required: true,
    },
  },
  computed: {
    typeLabel() {
      return this.activity.activity_type === 'scheduled_message'
        ? this.$t('ACTIVITIES.TYPE.SCHEDULED_MESSAGE')
        : this.$t('ACTIVITIES.TYPE.TASK');
    },
    typeIcon() {
      return this.activity.activity_type === 'scheduled_message' ? 'send-clock' : 'checkmark-circle';
    },
    isOverdue() {
      if (this.activity.status !== 'pending' || !this.activity.scheduled_at) return false;
      return isPast(parseISO(this.activity.scheduled_at));
    },
    statusLabel() {
      if (this.isOverdue) return this.$t('ACTIVITIES.FILTERS.OVERDUE');
      const key = `ACTIVITIES.STATUS.${this.activity.status?.toUpperCase()}`;
      return this.$t(key) !== key ? this.$t(key) : this.activity.status;
    },
    statusBadgeClass() {
      if (this.isOverdue || this.activity.status === 'failed') {
        return 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400';
      }
      if (this.activity.status === 'completed') {
        return 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400';
      }
      if (this.activity.status === 'cancelled') {
        return 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400';
      }
      return 'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400';
    },
    typeIconBgClass() {
      if (this.activity.activity_type === 'scheduled_message') {
        return 'bg-violet-100 dark:bg-violet-900/30';
      }
      return 'bg-sky-100 dark:bg-sky-900/30';
    },
    typeIconColorClass() {
      if (this.activity.activity_type === 'scheduled_message') {
        return 'text-violet-600 dark:text-violet-400';
      }
      return 'text-sky-600 dark:text-sky-400';
    },
    formattedScheduledAt() {
      if (!this.activity.scheduled_at) return '—';
      const date = parseISO(this.activity.scheduled_at);
      return `${format(date, "d 'de' MMMM 'de' yyyy", { locale: ptBR })} · ${format(date, 'HH:mm')}`;
    },
    formattedCreatedAt() {
      if (!this.activity.created_at) return '—';
      const date = parseISO(this.activity.created_at);
      return format(date, "d/MM/yyyy 'às' HH:mm", { locale: ptBR });
    },
    formattedCompletedAt() {
      if (!this.activity.completed_at) return '—';
      const date = parseISO(this.activity.completed_at);
      return format(date, "d/MM/yyyy 'às' HH:mm", { locale: ptBR });
    },
    conversationUrl() {
      if (!this.activity.conversation?.id) return null;
      return `/app/accounts/${this.accountId}/conversations/${this.activity.conversation.id}`;
    },
    pipelineStageLabel() {
      if (!this.activity.pipeline?.stage_id) return '';
      return this.$t('ACTIVITIES.DETAIL.STAGE', {
        stage: this.activity.pipeline.stage_id,
      });
    },
    pipelineKanbanLink() {
      if (!this.activity.pipeline?.id || !this.activity.contact?.id) return null;
      return buildKanbanDeepLink(this.accountId, {
        contactId: this.activity.contact.id,
        pipelineId: this.activity.pipeline.id,
        tab: 'activities',
      });
    },
    inboxLabel() {
      if (!this.activity.inbox) return '';
      return this.activity.inbox.name;
    },
    messagePreview() {
      if (!this.activity.message_content) return '';
      return this.activity.message_content.replace(/<[^>]*>/g, '').trim();
    },
    whatsappTemplateName() {
      return this.activity.metadata?.whatsapp?.template_params?.name || null;
    },
    failureReason() {
      const reason = this.activity.metadata?.failure_reason;
      if (!reason) return this.$t('ACTIVITIES.DETAIL.FAILURE_UNKNOWN');
      const key = FAILURE_REASON_KEYS[reason];
      return key ? this.$t(key) : reason;
    },
    hasPeopleSection() {
      return this.activity.assignee || this.activity.user;
    },
    canComplete() {
      return this.activity.status === 'pending';
    },
    canDelete() {
      return ['pending', 'failed'].includes(this.activity.status);
    },
  },
};
</script>
