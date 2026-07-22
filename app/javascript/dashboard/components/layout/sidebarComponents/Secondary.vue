<template>
  <div
    v-if="hasSecondaryMenu"
    class="h-full overflow-auto w-48 flex flex-col bg-white dark:bg-slate-900 border-r dark:border-slate-800/50 rtl:border-r-0 rtl:border-l border-slate-50 text-sm px-2 pb-8"
  >
    <account-context @toggle-accounts="toggleAccountModal" />
    <div v-if="showComposeButton" class="px-0 pt-2 pb-1">
      <button
        type="button"
        class="group flex items-center w-full p-2 text-sm font-medium leading-4 rounded-xl cursor-pointer
               text-slate-700 dark:text-slate-100
               border border-slate-100 dark:border-slate-800/80
               bg-slate-25/70 dark:bg-slate-800/40
               hover:bg-woot-25/60 dark:hover:bg-slate-800
               hover:border-woot-200 dark:hover:border-woot-700/40
               hover:shadow-sm
               transition-all duration-200 ease-smooth"
        @click="showComposeModal = true"
      >
        <fluent-icon
          icon="send"
          class="compose-quick-send-icon min-w-[1rem] mr-1.5 rtl:mr-0 rtl:ml-1.5 text-slate-700 dark:text-slate-100 group-hover:text-woot-500 dark:group-hover:text-woot-400"
          size="14"
        />
        {{ $t('COMPOSE_CONVERSATION.BUTTON_LABEL') }}
      </button>
    </div>
    <compose-conversation-launcher
      :show.sync="showComposeModal"
      @close="showComposeModal = false"
    />
    <transition-group
      name="menu-list"
      tag="ul"
      class="pt-2 list-none ml-0 mb-0"
    >
      <secondary-nav-item
        v-for="menuItem in accessibleMenuItems"
        :key="menuItem.toState"
        :menu-item="menuItem"
      />
      <secondary-nav-item
        v-for="menuItem in additionalSecondaryMenuItems[menuConfig.parentNav]"
        :key="menuItem.key"
        :menu-item="menuItem"
        @add-label="showAddLabelPopup"
      />
    </transition-group>
  </div>
</template>
<script>
import { frontendURL } from '../../../helper/URLHelper';
import SecondaryNavItem from './SecondaryNavItem.vue';
import AccountContext from './AccountContext.vue';
import ComposeConversationLauncher from 'dashboard/components/conversation/compose/ComposeConversationLauncher.vue';
import { mapGetters } from 'vuex';
import { FEATURE_FLAGS } from '../../../featureFlags';
import { hasPermissions } from '../../../helper/permissionsHelper';
import { routesWithPermissions } from '../../../routes';

export default {
  components: {
    AccountContext,
    SecondaryNavItem,
    ComposeConversationLauncher,
  },
  data() {
    return {
      showComposeModal: false,
    };
  },
  props: {
    accountId: {
      type: Number,
      default: 0,
    },
    labels: {
      type: Array,
      default: () => [],
    },
    accountForms: {
      type: Array,
      default: () => [],
    },
    inboxes: {
      type: Array,
      default: () => [],
    },
    teams: {
      type: Array,
      default: () => [],
    },
    customViews: {
      type: Array,
      default: () => [],
    },
    menuConfig: {
      type: Object,
      default: () => {},
    },
    currentUser: {
      type: Object,
      default: () => {},
    },
    isOnChatwootCloud: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    ...mapGetters({
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      currentRole: 'getCurrentRole',
    }),
    hasSecondaryMenu() {
      const hideSecondaryForRoutes = ['workflows_new', 'workflows_edit'];
      if (hideSecondaryForRoutes.includes(this.$route.name)) {
        return false;
      }
      return this.menuConfig.menuItems && this.menuConfig.menuItems.length;
    },
    contactCustomViews() {
      return this.customViews.filter(view => view.filter_type === 'contact');
    },
    accessibleMenuItems() {
      if (!this.currentRole) {
        return [];
      }
      const menuItemsFilteredByPermissions = this.menuConfig.menuItems.filter(
        menuItem => {
          const { permissions: userPermissions = [] } = this.currentUser;
          return hasPermissions(
            routesWithPermissions[menuItem.toStateName],
            userPermissions
          );
        }
      );
      return menuItemsFilteredByPermissions.filter(item => {
        if (item.showOnlyOnCloud) {
          return this.isOnChatwootCloud;
        }
        return true;
      });
    },

    showComposeButton() {
      return this.menuConfig.parentNav === 'conversations';
    },
    hideAllInboxForAgents() {
    return (
      this.isFeatureEnabledonAccount(
        this.accountId,
        'hide_all_inbox_for_agent'
      ) && this.currentRole !== 'administrator'
    );
  },
  inboxSection() {
    if (this.hideAllInboxForAgents && this.currentRole !== 'administrator') {
      return {};
    }
      return {
        icon: 'folder',
        label: 'INBOXES',
        hasSubMenu: true,
        newLink: this.showNewLink(FEATURE_FLAGS.INBOX_MANAGEMENT),
        newLinkTag: 'NEW_INBOX',
        key: 'inbox',
        toState: frontendURL(`accounts/${this.accountId}/settings/inboxes/new`),
        toStateName: 'settings_inbox_new',
        newLinkRouteName: 'settings_inbox_new',
        children: this.inboxes
          .map(inbox => ({
            id: inbox.id,
            label: inbox.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/inbox/${inbox.id}`
            ),
            type: inbox.channel_type,
            phoneNumber: inbox.phone_number,
            reauthorizationRequired: inbox.reauthorization_required,
            warningTooltipKey:
              inbox.channel_type === 'Channel::Api' &&
              inbox.reauthorization_required
                ? 'SIDEBAR.WHATSAPP_WEB_DISCONNECTED'
                : 'SIDEBAR.REAUTHORIZE',
            reconnectSettingsUrl:
              inbox.channel_type === 'Channel::Api' &&
              inbox.reauthorization_required
                ? frontendURL(
                    `accounts/${this.accountId}/settings/inboxes/${inbox.id}`,
                    { tab: 'quepasa' }
                  )
                : null,
          }))
          .sort((a, b) =>
            a.label.toLowerCase() > b.label.toLowerCase() ? 1 : -1
          ),
      };
    },
    labelSection() {
      return {
        icon: 'number-symbol',
        label: 'LABELS',
        hasSubMenu: true,
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_LABEL',
        key: 'label',
        toState: frontendURL(`accounts/${this.accountId}/settings/labels`),
        toStateName: 'labels_list',
        showModalForNewItem: true,
        modalName: 'AddLabel',
        dataTestid: 'sidebar-new-label-button',
        children: this.labels.map(label => ({
          id: label.id,
          label: label.title,
          color: label.color,
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/label/${label.title}`
          ),
        })),
      };
    },
    contactLabelSection() {
      return {
        icon: 'number-symbol',
        label: 'TAGGED_WITH',
        hasSubMenu: true,
        key: 'label',
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_LABEL',
        toState: frontendURL(`accounts/${this.accountId}/settings/labels`),
        toStateName: 'labels_list',
        showModalForNewItem: true,
        modalName: 'AddLabel',
        children: this.labels.map(label => ({
          id: label.id,
          label: label.title,
          color: label.color,
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/labels/${label.title}/contacts`
          ),
        })),
      };
    },
    contactFormSection() {
      if (
        !this.isFeatureEnabledonAccount(this.accountId, FEATURE_FLAGS.WORKFLOWS)
      ) {
        return null;
      }

      const formsWithSubmissions = this.accountForms
        .filter(form => (form.submissions_count || 0) > 0)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name, 'pt-BR'));

      if (!formsWithSubmissions.length) {
        return null;
      }

      return {
        icon: 'document',
        label: 'SUBMITTED_VIA_FORM',
        hasSubMenu: true,
        key: 'account_form',
        children: formsWithSubmissions.map(form => ({
          id: form.id,
          label: form.name,
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/forms/${form.id}/contacts`
          ),
        })),
      };
    },
    teamSection() {
      return {
        icon: 'people-team',
        label: 'TEAMS',
        hasSubMenu: true,
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_TEAM',
        key: 'team',
        toState: frontendURL(`accounts/${this.accountId}/settings/teams/new`),
        toStateName: 'settings_teams_new',
        newLinkRouteName: 'settings_teams_new',
        children: this.teams.map(team => ({
          id: team.id,
          label: team.name,
          truncateLabel: true,
          toState: frontendURL(`accounts/${this.accountId}/team/${team.id}`),
        })),
      };
    },
    foldersSection() {
      return {
        icon: 'folder',
        label: 'CUSTOM_VIEWS_FOLDER',
        hasSubMenu: true,
        key: 'custom_view',
        children: this.customViews
          .filter(view => view.filter_type === 'conversation')
          .map(view => ({
            id: view.id,
            label: view.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/custom_view/${view.id}`
            ),
          })),
      };
    },
    contactSegmentsSection() {
      return {
        icon: 'folder',
        label: 'CUSTOM_VIEWS_SEGMENTS',
        hasSubMenu: true,
        key: 'custom_view',
        children: this.customViews
          .filter(view => view.filter_type === 'contact')
          .map(view => ({
            id: view.id,
            label: view.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/contacts/custom_view/${view.id}`
            ),
          })),
      };
    },
    additionalSecondaryMenuItems() {
      let conversationMenuItems = [this.inboxSection, this.labelSection];
      let contactMenuItems = [];
      if (this.contactFormSection) {
        contactMenuItems.push(this.contactFormSection);
      }
      contactMenuItems.push(this.contactLabelSection);
      if (this.teams.length) {
        conversationMenuItems = [this.teamSection, ...conversationMenuItems];
      }
      if (this.customViews.length) {
        conversationMenuItems = [this.foldersSection, ...conversationMenuItems];
      }
      if (this.contactCustomViews.length) {
        contactMenuItems = [this.contactSegmentsSection, ...contactMenuItems];
      }
      return {
        conversations: conversationMenuItems,
        contacts: contactMenuItems,
      };
    },
  },
  methods: {
    showAddLabelPopup() {
      this.$emit('add-label');
    },
    toggleAccountModal() {
      this.$emit('toggle-accounts');
    },
    showNewLink(featureFlag) {
      return this.isFeatureEnabledonAccount(this.accountId, featureFlag);
    },
  },
};
</script>

<style scoped>
@keyframes compose-quick-send {
  0%,
  100% {
    transform: translateX(0);
  }

  50% {
    transform: translateX(4px);
  }
}

@keyframes compose-quick-send-rtl {
  0%,
  100% {
    transform: translateX(0);
  }

  50% {
    transform: translateX(-4px);
  }
}

.group:hover .compose-quick-send-icon {
  animation: compose-quick-send 0.9s ease-in-out infinite;
}

[dir='rtl'] .group:hover .compose-quick-send-icon {
  animation-name: compose-quick-send-rtl;
}

@media (prefers-reduced-motion: reduce) {
  .group:hover .compose-quick-send-icon {
    animation: none;
  }
}
</style>
