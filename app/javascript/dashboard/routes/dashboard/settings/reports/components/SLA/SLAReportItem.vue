<script setup>
import { computed } from 'vue';
import UserAvatarWithName from 'dashboard/components/widgets/UserAvatarWithName.vue';
import CardLabels from 'dashboard/components/widgets/conversation/conversationCardComponents/CardLabels.vue';
import SLAViewDetails from './SLAViewDetails.vue';

const props = defineProps({
  slaName: {
    type: String,
    required: true,
  },
  conversationId: {
    type: Number,
    required: true,
  },
  conversation: {
    type: Object,
    required: true,
  },
  slaEvents: {
    type: Array,
    default: () => [],
  },
});

const contactName = computed(() => props.conversation.contact?.name || '—');

const hasLabels = computed(() => Boolean(props.conversation.labels));

const routerParams = computed(() => ({
  name: 'inbox_conversation',
  params: { conversation_id: props.conversationId },
}));
</script>

<template>
  <div
    class="grid items-center content-center w-full h-16 grid-cols-12 gap-4 px-6 py-0 bg-white border-b last:border-b-0 last:rounded-b-xl border-slate-75 dark:border-slate-800/50 dark:bg-slate-900"
  >
    <div
      class="flex items-center gap-2 min-w-0 col-span-6 px-0 py-2 text-sm tracking-[0.5] text-slate-700 dark:text-slate-100 rtl:text-right"
    >
      <router-link
        :to="routerParams"
        class="shrink-0 font-medium text-woot-500 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500/50 rounded-sm"
      >
        {{ `#${conversationId}` }}
      </router-link>
      <span class="shrink-0 text-slate-600 dark:text-slate-300">
        {{ $t('SLA_REPORTS.WITH') }}
      </span>
      <span
        class="capitalize truncate min-w-0 text-slate-700 dark:text-slate-200"
        :title="contactName"
      >
        {{ contactName }}
      </span>
      <CardLabels
        v-if="hasLabels"
        class="w-[60%] min-w-0"
        :conversation-id="conversationId"
        :conversation-labels="conversation.labels"
      />
    </div>
    <div
      class="flex items-center min-w-0 capitalize py-2 px-0 text-sm tracking-[0.5] text-slate-700 dark:text-slate-50 text-left rtl:text-right col-span-2"
    >
      <span class="truncate" :title="slaName">{{ slaName }}</span>
    </div>
    <div class="flex items-center col-span-2 gap-2 min-w-0">
      <UserAvatarWithName
        v-if="conversation.assignee"
        :user="conversation.assignee"
      />
      <span v-else class="text-slate-600 dark:text-slate-200"> — </span>
    </div>
    <SLAViewDetails :sla-events="slaEvents" />
  </div>
</template>
