<template>
  <div class="mb-4">
    <button
      class="group text-white/75 dark:text-slate-300 w-10 h-10 my-1 p-0 flex items-center justify-center rounded-xl cursor-pointer relative transition-all duration-200 ease-out hover:bg-white/15 hover:text-white dark:hover:bg-white/10 dark:hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 focus-visible:ring-offset-2 focus-visible:ring-offset-woot-600 dark:focus-visible:ring-offset-woot-800 motion-reduce:transition-none"
      :class="{
        'bg-white text-woot-600 shadow-sm hover:bg-white hover:text-woot-600 dark:bg-slate-100 dark:text-woot-600 dark:hover:bg-slate-100 dark:shadow-md dark:shadow-woot-500/15':
          isNotificationPanelActive,
      }"
      @click="openNotificationPanel"
    >
      <fluent-icon
        icon="alert"
        class="transition-all duration-200 ease-out motion-reduce:transition-none motion-reduce:transform-none"
        :class="
          isNotificationPanelActive
            ? 'text-woot-600 scale-100 opacity-100'
            : 'opacity-80 group-hover:opacity-100 group-hover:scale-110 group-hover:text-white dark:group-hover:text-white'
        "
      />
      <span
        v-if="unreadCount"
        class="text-slate-900 bg-yellow-400 absolute -top-0.5 -right-1 text-xxs min-w-[1rem] rounded-full px-1 font-semibold"
      >
        {{ unreadCount }}
      </span>
    </button>
  </div>
</template>
<script>
import { mapGetters } from 'vuex';

export default {
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      notificationMetadata: 'notifications/getMeta',
    }),
    unreadCount() {
      if (!this.notificationMetadata.unreadCount) {
        return '';
      }

      return this.notificationMetadata.unreadCount < 100
        ? `${this.notificationMetadata.unreadCount}`
        : '99+';
    },
    isNotificationPanelActive() {
      return this.$route.name === 'notifications_index';
    },
  },
  methods: {
    openNotificationPanel() {
      if (this.$route.name !== 'notifications_index') {
        this.$emit('open-notification-panel');
      }
    },
  },
};
</script>
