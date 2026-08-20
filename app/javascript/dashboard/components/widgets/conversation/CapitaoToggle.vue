<script>
import { mapGetters } from 'vuex';
import { mixin as clickaway } from 'vue-clickaway';
import { useAlert } from 'dashboard/composables';
import Thumbnail from '../Thumbnail.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import wootConstants from 'dashboard/constants/globals';

export default {
  components: {
    Thumbnail,
    WootDropdownItem,
    WootDropdownMenu,
  },
  mixins: [clickaway],
  props: {
    conversationId: {
      type: [String, Number],
      required: true,
    },
    inboxId: {
      type: [String, Number],
      required: true,
    },
    status: {
      type: String,
      default: '',
    },
    capitaoEnabled: {
      type: Boolean,
      default: true,
    },
    capitaoAgent: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      isToggling: false,
      showMenu: false,
    };
  },
  computed: {
    ...mapGetters({
      getActiveAgentBot: 'agentBots/getActiveAgentBot',
    }),
    agentBot() {
      return this.getActiveAgentBot(this.inboxId) || {};
    },
    isCapitaoOn() {
      return this.capitaoEnabled === true;
    },
    isCapitaoBot() {
      return Boolean(this.agentBot.capitao);
    },
    availableAgents() {
      const agents = this.agentBot.bot_config?.agents;
      if (!Array.isArray(agents)) return [];

      return agents
        .filter(agent => agent && agent.id && agent.name)
        .map(agent => ({
          id: String(agent.id),
          name: String(agent.name),
          default: Boolean(agent.default),
        }));
    },
    hasAgents() {
      return this.availableAgents.length > 0;
    },
    selectedAgentName() {
      return this.capitaoAgent?.name || '';
    },
    isVisible() {
      const activeStatuses = [
        wootConstants.STATUS_TYPE.OPEN,
        wootConstants.STATUS_TYPE.PENDING,
      ];
      return (
        activeStatuses.includes(this.status) &&
        Boolean(this.agentBot.id) &&
        this.isCapitaoBot
      );
    },
    tooltipText() {
      if (this.isCapitaoOn && this.selectedAgentName) {
        return this.$t('CONVERSATION.CAPITAO.ACTIVE_TOOLTIP', {
          agent: this.selectedAgentName,
        });
      }

      return this.isCapitaoOn
        ? this.$t('CONVERSATION.CAPITAO.ACTIVE_FALLBACK_TOOLTIP')
        : this.$t('CONVERSATION.CAPITAO.PAUSED_TOOLTIP');
    },
    pauseActionLabel() {
      return this.selectedAgentName
        ? this.$t('CONVERSATION.CAPITAO.PAUSE_ACTION_WITH_AGENT', {
            agent: this.selectedAgentName,
          })
        : this.$t('CONVERSATION.CAPITAO.PAUSE_ACTION');
    },
  },
  watch: {
    inboxId: {
      immediate: true,
      handler(inboxId) {
        if (inboxId) {
          this.fetchAgentBot();
        }
      },
    },
    conversationId() {
      this.showMenu = false;
      if (this.inboxId) {
        this.fetchAgentBot();
      }
    },
  },
  methods: {
    fetchAgentBot() {
      this.$store.dispatch('agentBots/fetchAgentBotInbox', this.inboxId);
    },
    closeMenu() {
      this.showMenu = false;
    },
    onMainClick() {
      if (this.isToggling) return;

      if (this.hasAgents) {
        this.showMenu = !this.showMenu;
        return;
      }

      this.toggleCapitao(!this.isCapitaoOn);
    },
    async selectAgent(agent) {
      this.showMenu = false;
      await this.toggleCapitao(true, agent);
    },
    async pauseCapitao() {
      this.showMenu = false;
      await this.toggleCapitao(false);
    },
    async toggleCapitao(enabled, agent = null) {
      if (this.isToggling) return;

      this.isToggling = true;
      try {
        await this.$store.dispatch('toggleCapitao', {
          conversationId: this.conversationId,
          enabled,
          agent: agent
            ? {
                id: agent.id,
                name: agent.name,
              }
            : undefined,
        });
        useAlert(
          enabled
            ? agent?.name || this.selectedAgentName
              ? this.$t('CONVERSATION.CAPITAO.ACTIVATED_WITH_AGENT', {
                  agent: agent?.name || this.selectedAgentName,
                })
              : this.$t('CONVERSATION.CAPITAO.ACTIVATED')
            : this.selectedAgentName
              ? this.$t('CONVERSATION.CAPITAO.PAUSED_WITH_AGENT', {
                  agent: this.selectedAgentName,
                })
              : this.$t('CONVERSATION.CAPITAO.PAUSED')
        );
      } catch (error) {
        useAlert(this.$t('CONVERSATION.CAPITAO.ERROR'));
      } finally {
        this.isToggling = false;
      }
    },
  },
};
</script>

<template>
  <div v-if="isVisible" v-on-clickaway="closeMenu" class="capitao-toggle-wrap">
    <button
      v-tooltip.left="tooltipText"
      type="button"
      class="capitao-toggle"
      :class="{
        'is-active': isCapitaoOn,
        'is-paused': !isCapitaoOn,
      }"
      :aria-label="tooltipText"
      :aria-expanded="showMenu ? 'true' : 'false'"
      :disabled="isToggling"
      @click="onMainClick"
    >
      <Thumbnail
        :src="agentBot.avatar_url"
        :username="agentBot.name || 'Capitão'"
        size="28px"
      />
      <span v-if="isCapitaoOn && selectedAgentName" class="capitao-agent-name">
        {{ selectedAgentName }}
      </span>
    </button>

    <div
      v-if="showMenu && hasAgents"
      class="dropdown-pane dropdown-pane--open capitao-menu"
    >
      <p class="capitao-menu-title">
        {{ $t('CONVERSATION.CAPITAO.SELECT_AGENT') }}
      </p>
      <woot-dropdown-menu class="mb-0">
        <woot-dropdown-item
          v-for="agent in availableAgents"
          :key="agent.id"
        >
          <button
            type="button"
            class="capitao-menu-item"
            :class="{
              'is-selected':
                isCapitaoOn && capitaoAgent && String(capitaoAgent.id) === agent.id,
            }"
            @click="selectAgent(agent)"
          >
            {{ agent.name }}
          </button>
        </woot-dropdown-item>
        <woot-dropdown-item v-if="isCapitaoOn">
          <button
            type="button"
            class="capitao-menu-item is-pause"
            @click="pauseCapitao"
          >
            {{ pauseActionLabel }}
          </button>
        </woot-dropdown-item>
      </woot-dropdown-menu>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.capitao-toggle-wrap {
  @apply relative inline-flex items-center;
}

.capitao-toggle {
  @apply inline-flex items-center justify-center gap-1.5 p-0 bg-transparent border-0 rounded-full cursor-pointer transition-opacity duration-150;

  &:disabled {
    @apply cursor-wait;
  }

  &.is-active {
    @apply ring-2 ring-green-500 ring-offset-1 dark:ring-offset-slate-900;
  }

  &.is-paused {
    @apply opacity-50 hover:opacity-80;
  }
}

.capitao-agent-name {
  @apply max-w-[7rem] truncate text-xs font-medium text-slate-700 dark:text-slate-100 pr-1;
}

.capitao-menu {
  @apply absolute right-0 top-full z-50 mt-2 min-w-[12rem] p-2;
}

.capitao-menu-title {
  @apply m-0 mb-1 px-2 text-xs font-medium text-slate-500 dark:text-slate-400;
}

.capitao-menu-item {
  @apply w-full rounded-md border-0 bg-transparent px-2 py-1.5 text-left text-sm text-slate-800 dark:text-slate-100 cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700;

  &.is-selected {
    @apply font-semibold text-woot-600 dark:text-woot-300;
  }

  &.is-pause {
    @apply text-red-600 dark:text-red-400;
  }
}
</style>
