<template>
  <div
    class="primary-sidebar h-full w-14 bg-woot-600 dark:bg-woot-800 border-r border-woot-700/30 dark:border-woot-700/40 dark:shadow-[inset_-1px_0_0_0_rgba(255,255,255,0.05)] rtl:border-l rtl:border-r-0 rounded-r-md flex justify-between flex-col"
  >
    <div class="flex flex-col items-center">
      <logo
        :source="logoSource"
        :name="installationName"
        :account-id="accountId"
        class="m-4 mb-10"
      />
      <primary-nav-item
        v-for="menuItem in menuItems"
        :key="menuItem.toState"
        :icon="menuItem.icon"
        :name="menuItem.label"
        :to="menuItem.toState"
        :is-child-menu-active="menuItem.key === activeMenuItem"
        :beta="menuItem.beta"
      />
    </div>
    <div class="flex flex-col items-center justify-end pb-6">
      <primary-nav-item
        icon="book-open-globe"
        name="DOCS"
        :open-in-new-page="true"
        :to="helpDocsURL"
      />
      <notification-bell @open-notification-panel="openNotificationPanel" />
      <agent-details @toggle-menu="toggleOptions" />
      <options-menu
        :show="showOptionsMenu"
        @toggle-accounts="toggleAccountModal"
        @show-support-chat-window="toggleSupportChatWindow"
        @key-shortcut-modal="$emit('key-shortcut-modal')"
        @open-announcements-modal="openAnnouncementsModal"
        @close="toggleOptions"
      />
    </div>
  </div>
</template>
<script>
import Logo from './Logo.vue';
import PrimaryNavItem from './PrimaryNavItem.vue';
import OptionsMenu from './OptionsMenu.vue';
import AgentDetails from './AgentDetails.vue';
import NotificationBell from './NotificationBell.vue';
import wootConstants from 'dashboard/constants/globals';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { ACCOUNT_EVENTS } from '../../../helper/AnalyticsHelper/events';

export default {
  components: {
    Logo,
    PrimaryNavItem,
    OptionsMenu,
    AgentDetails,
    NotificationBell,
  },
  props: {
    isACustomBrandedInstance: {
      type: Boolean,
      default: false,
    },
    logoSource: {
      type: String,
      default: '',
    },
    installationName: {
      type: String,
      default: '',
    },
    accountId: {
      type: Number,
      default: 0,
    },
    menuItems: {
      type: Array,
      default: () => [],
    },
    activeMenuItem: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      helpDocsURL: wootConstants.DOCS_URL,
      showOptionsMenu: false,
    };
  },
  methods: {
    frontendURL,
    toggleOptions() {
      this.showOptionsMenu = !this.showOptionsMenu;
    },
    toggleAccountModal() {
      this.$emit('toggle-accounts');
    },
    toggleSupportChatWindow() {
      window.$chatwoot.toggle();
    },
    openNotificationPanel() {
      this.$track(ACCOUNT_EVENTS.OPENED_NOTIFICATIONS);
      this.$emit('open-notification-panel');
    },
    openAnnouncementsModal() {
      this.$emit('open-announcements-modal');
    },
  },
};
</script>
