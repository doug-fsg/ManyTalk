<template>
  <div class="relative">
    <div class="flex items-center gap-2 px-3 py-2">
      <woot-sidemenu-icon
        size="tiny"
        class="relative top-0 ltr:-ml-0.5 rtl:-mr-0.5"
      />
      <div
        class="search-field group relative flex flex-1 items-center h-9 rounded-lg bg-slate-50 dark:bg-slate-800/40 transition-shadow duration-200 focus-within:ring-1 focus-within:ring-slate-100 dark:focus-within:ring-slate-600/60 rtl:mr-1"
        role="search"
      >
        <label :for="inputId" class="sr-only">
          {{ $t('CONVERSATION.SEARCH_MESSAGES') }}
        </label>
        <fluent-icon
          icon="search"
          class="pointer-events-none absolute ltr:left-3 rtl:right-3 flex-shrink-0 text-slate-400 dark:text-slate-500"
          size="14"
          aria-hidden="true"
        />
        <input
          :id="inputId"
          type="search"
          readonly
          tabindex="0"
          :placeholder="$t('CONVERSATION.SEARCH_MESSAGES')"
          class="search-field__input w-full h-full ltr:pl-9 ltr:pr-[4.25rem] rtl:pr-9 rtl:pl-[4.25rem] text-xs bg-transparent border-0 rounded-lg shadow-none text-slate-700 dark:text-slate-200 placeholder:text-slate-400 dark:placeholder:text-slate-500 cursor-text"
          @focus="openSearch"
          @click="openSearch"
        />
        <div
          class="pointer-events-none absolute flex items-center gap-0.5 ltr:right-2.5 rtl:left-2.5"
          aria-hidden="true"
        >
          <hotkey :custom-class="shortcutKeyClass">
            {{ modKeyLabel }}
          </hotkey>
          <hotkey :custom-class="shortcutKeyClass">K</hotkey>
        </div>
      </div>
      <switch-layout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="$emit('toggle-conversation-layout')"
      />
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import SwitchLayout from './SwitchLayout.vue';
import Hotkey from 'dashboard/components/base/Hotkey.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';

let searchInputCounter = 0;

export default {
  components: {
    SwitchLayout,
    Hotkey,
  },
  props: {
    isOnExpandedLayout: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    searchInputCounter += 1;
    return {
      inputId: `conversation-search-${searchInputCounter}`,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
    }),
    searchUrl() {
      return frontendURL(`accounts/${this.accountId}/search`);
    },
    modKeyLabel() {
      return /Mac|iPhone|iPod|iPad/i.test(navigator.userAgent) ? '⌘' : 'Ctrl';
    },
    shortcutKeyClass() {
      return 'h-5 min-w-[1.25rem] px-1 text-xxs font-medium text-slate-400 dark:text-slate-500 bg-slate-100/80 dark:bg-slate-700/60 border-0 rounded';
    },
  },
  methods: {
    openSearch(event) {
      event.target.blur();
      if (this.$route.path !== this.searchUrl) {
        this.$router.push(this.searchUrl);
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.search-field__input {
  @apply m-0 outline-none;

  &,
  &:hover,
  &:focus,
  &:active {
    @apply border-transparent shadow-none ring-0;
  }

  &::-webkit-search-cancel-button,
  &::-webkit-search-decoration {
    display: none;
  }
}
</style>
