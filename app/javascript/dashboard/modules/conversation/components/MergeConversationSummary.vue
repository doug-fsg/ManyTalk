<template>
  <div
    v-if="parentConversationId"
    class="my-4 relative p-2.5 border rounded-[4px] text-slate-800 dark:text-slate-100 border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800"
  >
    <h5 class="text-base font-medium text-slate-900 dark:text-white">
      {{ $t('MERGE_CONVERSATIONS.SUMMARY.TITLE') }}
    </h5>
    <ul class="ml-0 list-none">
      <li>
        <span class="inline-block mr-1">❌</span>
        <span
          v-dompurify-html="
            $t('MERGE_CONVERSATIONS.SUMMARY.DELETE_WARNING', {
              primaryConversationId,
            })
          "
        />
      </li>
      <li>
        <span class="inline-block mr-1">✅</span>
        <span
          v-dompurify-html="
            $t('MERGE_CONVERSATIONS.SUMMARY.ATTRIBUTE_WARNING', {
              primaryConversationId,
              parentConversationId,
            })
          "
        />
      </li>
      <li>
        <span class="inline-block mr-1">🏷️</span>
        <span v-dompurify-html="$t('MERGE_CONVERSATIONS.SUMMARY.LABELS_WARNING')" />
      </li>
    </ul>
  </div>
</template>

<script>
export default {
  props: {
    primaryConversationId: {
      type: [Number, String],
      default: '',
    },
    parentConversationId: {
      type: [Number, String],
      default: '',
    },
  },
};
</script>
