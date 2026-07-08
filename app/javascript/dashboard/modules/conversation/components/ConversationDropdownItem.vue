<template>
  <div class="flex flex-col gap-0.5 py-1">
    <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
      #{{ conversation.id }}
    </span>
    <span class="text-xs text-slate-600 dark:text-slate-300">
      {{ statusLabel }} · {{ lastMessagePreview }}
    </span>
  </div>
</template>

<script>
export default {
  props: {
    conversation: {
      type: Object,
      required: true,
    },
  },
  computed: {
    statusLabel() {
      const translationKey = `CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${this.conversation.status}.TEXT`;
      return this.$te(translationKey)
        ? this.$t(translationKey)
        : this.conversation.status;
    },
    lastMessagePreview() {
      const lastMessage = this.conversation.messages?.[0];
      if (!lastMessage?.content) {
        return this.$t('CHAT_LIST.NO_CONTENT');
      }

      return lastMessage.content.slice(0, 80);
    },
  },
};
</script>
