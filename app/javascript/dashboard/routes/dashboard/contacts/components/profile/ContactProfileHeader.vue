<script setup>
import { computed } from 'vue';
import { useRouter } from 'dashboard/composables/route';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';

const props = defineProps({
  contact: {
    type: Object,
    required: true,
  },
  accountId: {
    type: [String, Number],
    required: true,
  },
  primaryStage: {
    type: String,
    default: null,
  },
  stageColor: {
    type: String,
    default: '#6B7280',
  },
  primaryPipelineName: {
    type: String,
    default: null,
  },
  formOriginName: {
    type: String,
    default: null,
  },
  pendingActivitiesCount: {
    type: Number,
    default: 0,
  },
  overdueActivitiesCount: {
    type: Number,
    default: 0,
  },
  hasPipeline: {
    type: Boolean,
    default: false,
  },
  kanbanDeepLink: {
    type: Object,
    default: null,
  },
});

const router = useRouter();

const stageBadgeStyle = computed(() => ({
  backgroundColor: `${props.stageColor}20`,
  color: props.stageColor,
  borderColor: `${props.stageColor}40`,
}));

const openKanban = () => {
  if (!props.kanbanDeepLink) return;
  router.push(props.kanbanDeepLink);
};
</script>

<template>
  <div
    class="border-b border-slate-100 bg-white px-6 py-3 dark:border-slate-800 dark:bg-slate-900"
  >
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="min-w-0 flex flex-wrap items-center gap-2">
        <span
          v-if="primaryStage"
          class="inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium"
          :style="stageBadgeStyle"
        >
          {{ primaryStage }}
        </span>
        <span
          v-if="primaryPipelineName"
          class="inline-flex items-center gap-1 text-xs text-slate-500 dark:text-slate-400"
        >
          <FluentIcon icon="board" size="12" />
          {{ primaryPipelineName }}
        </span>
        <span
          v-if="overdueActivitiesCount > 0"
          class="inline-flex items-center rounded-full border border-red-200 bg-red-50 px-2 py-0.5 text-[11px] font-medium text-red-700 dark:border-red-800 dark:bg-red-900/30 dark:text-red-300"
        >
          {{
            $t('CONTACT_PROFILE.HEADER.OVERDUE_ACTIVITIES', {
              count: overdueActivitiesCount,
            })
          }}
        </span>
        <span
          v-else-if="pendingActivitiesCount > 0"
          class="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-[11px] text-slate-600 dark:bg-slate-800 dark:text-slate-300"
        >
          {{
            $t('CONTACT_PROFILE.HEADER.PENDING_ACTIVITIES', {
              count: pendingActivitiesCount,
            })
          }}
        </span>
        <span
          v-if="formOriginName"
          class="inline-flex items-center gap-1 text-xs text-slate-500 dark:text-slate-400"
        >
          <FluentIcon icon="document" size="12" />
          {{
            $t('CONTACT_PROFILE.HEADER.VIA_FORM', {
              form: formOriginName,
            })
          }}
        </span>
      </div>

      <woot-button
        v-if="hasPipeline"
        icon="board"
        size="small"
        variant="smooth"
        color-scheme="secondary"
        @click="openKanban"
      >
        {{ $t('CONTACT_PROFILE.HEADER.OPEN_IN_PIPELINE') }}
      </woot-button>
    </div>
  </div>
</template>
