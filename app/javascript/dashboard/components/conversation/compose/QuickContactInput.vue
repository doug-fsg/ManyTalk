<template>
  <div class="px-8 pt-4 pb-2">
    <div class="flex items-center justify-between gap-3 mb-2">
      <label class="text-sm font-medium text-slate-700 dark:text-slate-300">
        {{ $t('COMPOSE_CONVERSATION.SEARCH_LABEL') }}
      </label>
      <div class="flex items-center gap-1 text-xs">
        <button
          type="button"
          class="px-2 py-1 rounded-md cursor-pointer transition-colors duration-200"
          :class="inputMode === 'phone'
            ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'"
          @click="setInputMode('phone')"
        >
          {{ $t('COMPOSE_CONVERSATION.MODE_PHONE') }}
        </button>
        <button
          type="button"
          class="px-2 py-1 rounded-md cursor-pointer transition-colors duration-200"
          :class="inputMode === 'search'
            ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'"
          @click="setInputMode('search')"
        >
          {{ $t('COMPOSE_CONVERSATION.MODE_NAME') }}
        </button>
      </div>
    </div>

    <div
      v-if="selectedContact"
      class="flex items-center gap-2 min-h-[2.5rem] px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/60"
    >
      <woot-thumbnail
        :src="selectedContact.thumbnail"
        :username="selectedContact.name"
        size="28px"
      />
      <div class="flex-1 min-w-0">
        <div class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
          {{ contactDisplayLabel(selectedContact) }}
        </div>
        <div
          v-if="isCreatingContact"
          class="text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('COMPOSE_CONVERSATION.CREATING_CONTACT') }}
        </div>
      </div>
      <button
        type="button"
        class="p-1 rounded-md text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 cursor-pointer transition-colors duration-200"
        :disabled="isCreatingContact"
        @click="$emit('clear')"
      >
        <fluent-icon icon="dismiss" size="16" />
      </button>
    </div>

    <div v-else ref="inputAnchor" class="relative">
      <woot-phone-input
        v-if="inputMode === 'phone'"
        ref="phoneInput"
        v-model="phoneNumber"
        :value="phoneNumber"
        default-country-code="BR"
        fixed-country-dropdown
        digits-only
        class="compose-phone-input"
        :placeholder="$t('COMPOSE_CONVERSATION.PHONE_PLACEHOLDER')"
        @input="onPhoneInput"
        @setCode="onDialCodeChange"
        @enter="onEnterKey"
      />

      <div v-else class="relative">
        <input
          ref="queryInput"
          v-model="searchQuery"
          type="text"
          :placeholder="$t('COMPOSE_CONVERSATION.NAME_SEARCH_PLACEHOLDER')"
          class="w-full px-4 py-2.5 pl-10 border border-slate-200 dark:border-slate-700 rounded-lg
                 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500
                 bg-white dark:bg-slate-800 text-slate-900 dark:text-white text-sm
                 transition-colors duration-200"
          :disabled="isCreatingContact"
          @input="onInputSearch"
          @keydown.enter.prevent="onEnterKey"
        />
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <fluent-icon icon="search" size="16" class="text-slate-400" />
        </div>
      </div>

      <div
        v-if="isLoading || isCreatingContact"
        class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none"
      >
        <div
          class="animate-spin w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full"
        />
      </div>

      <div
        v-if="showResultsDropdown"
        :style="dropdownStyles"
        class="overflow-hidden rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-lg"
      >
        <div class="max-h-60 overflow-y-auto">
          <div
            v-if="isLoading"
            class="px-4 py-3 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ $t('CONTACTS_PAGE.LIST.LOADING_MESSAGE') }}
          </div>

          <div
            v-else-if="showEmptySearchResult && !showQuickCreateOption"
            class="px-4 py-3 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ $t('CONTACTS_PAGE.LIST.404') }}
          </div>

          <ul v-else class="list-none m-0 p-1">
            <li
              v-for="contact in localContacts"
              :key="contact.id"
              class="flex items-center gap-3 px-3 py-2.5 cursor-pointer rounded-md
                     hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors duration-200"
              @click="selectContact(contact)"
            >
              <woot-thumbnail
                :src="contact.thumbnail"
                :username="contact.name"
                size="28px"
              />
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                  {{ contactDisplayLabel(contact) }}
                </div>
              </div>
            </li>

            <li
              v-if="showQuickCreateOption"
              class="flex items-center gap-3 px-3 py-2.5 cursor-pointer rounded-md
                     border-t border-slate-100 dark:border-slate-700
                     hover:bg-woot-25 dark:hover:bg-woot-900/20 transition-colors duration-200"
              @click="createQuickContact"
            >
              <span
                class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-woot-50 dark:bg-woot-900/30"
              >
                <fluent-icon icon="add" size="14" class="text-woot-500" />
              </span>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-woot-600 dark:text-woot-400">
                  {{ $t('COMPOSE_CONVERSATION.START_WITH', { value: quickCreateDisplayValue }) }}
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <p
      v-if="showSearchHint && !selectedContact"
      class="mt-2 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ searchHintText }}
    </p>
  </div>
</template>

<script>
import debounce from 'lodash/debounce';
import {
  buildFullPhoneNumber,
  canQuickCreateContact,
  contactDisplayLabel,
  getMinSearchLength,
  quickCreateLabel,
  searchContacts,
} from './helpers/composeConversationHelper';

export default {
  name: 'QuickContactInput',
  props: {
    selectedContact: {
      type: Object,
      default: null,
    },
    isCreatingContact: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      inputMode: 'phone',
      searchQuery: '',
      phoneNumber: '',
      activeDialCode: '+55',
      localContacts: [],
      isLoading: false,
      hasSearched: false,
      dropdownStyles: {},
    };
  },
  computed: {
    activeQuery() {
      if (this.inputMode === 'phone') {
        return buildFullPhoneNumber(this.activeDialCode, this.phoneNumber);
      }

      return this.searchQuery.trim();
    },
    trimmedQuery() {
      return this.activeQuery.trim();
    },
    minSearchLength() {
      if (this.inputMode === 'phone') {
        return getMinSearchLength(this.phoneNumber);
      }

      return getMinSearchLength(this.searchQuery);
    },
    isQueryTooShort() {
      const value =
        this.inputMode === 'phone'
          ? this.phoneNumber.replace(/^\+/, '').trim()
          : this.trimmedQuery;

      return value.length > 0 && value.length < this.minSearchLength;
    },
    showSearchHint() {
      return (
        !this.selectedContact &&
        this.inputMode === 'search' &&
        this.trimmedQuery.length === 0
      );
    },
    searchHintText() {
      return this.$t('COMPOSE_CONVERSATION.NAME_SEARCH_HINT');
    },
    showResultsDropdown() {
      return (
        !this.selectedContact &&
        !this.isQueryTooShort &&
        (this.isLoading || this.hasSearched)
      );
    },
    showEmptySearchResult() {
      return (
        !this.isLoading &&
        this.hasSearched &&
        this.localContacts.length === 0 &&
        !this.isQueryTooShort
      );
    },
    showQuickCreateOption() {
      return (
        !this.isLoading &&
        this.hasSearched &&
        canQuickCreateContact(this.activeQuery)
      );
    },
    quickCreateDisplayValue() {
      return quickCreateLabel(this.activeQuery);
    },
  },
  watch: {
    showResultsDropdown(isVisible) {
      if (isVisible) {
        this.$nextTick(() => {
          this.updateDropdownPosition();
        });
      }
    },
  },
  mounted() {
    window.addEventListener('resize', this.updateDropdownPosition);
    window.addEventListener('scroll', this.updateDropdownPosition, true);
    this.$nextTick(() => {
      this.focusInput();
    });
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.updateDropdownPosition);
    window.removeEventListener('scroll', this.updateDropdownPosition, true);
  },
  methods: {
    contactDisplayLabel,
    updateDropdownPosition() {
      const anchor = this.$refs.inputAnchor;
      if (!anchor || !this.showResultsDropdown) {
        return;
      }

      const rect = anchor.getBoundingClientRect();
      this.dropdownStyles = {
        position: 'fixed',
        top: `${rect.bottom + 4}px`,
        left: `${rect.left}px`,
        width: `${rect.width}px`,
        zIndex: 10000,
      };
    },
    setInputMode(mode) {
      this.inputMode = mode;
      this.localContacts = [];
      this.hasSearched = false;
      this.isLoading = false;

      this.$nextTick(() => {
        this.focusInput();
      });
    },
    focusInput() {
      if (this.inputMode === 'phone') {
        this.$refs.phoneInput?.$refs?.phoneNumberInput?.focus();
        return;
      }

      this.$refs.queryInput?.focus();
    },
    resetState() {
      this.inputMode = 'phone';
      this.searchQuery = '';
      this.phoneNumber = '';
      this.activeDialCode = '+55';
      this.localContacts = [];
      this.isLoading = false;
      this.hasSearched = false;
      this.$nextTick(() => {
        this.focusInput();
      });
    },
    onDialCodeChange(dialCode) {
      this.activeDialCode = dialCode || '+55';
      this.onInputSearch();
    },
    onPhoneInput(value, dialCode) {
      this.phoneNumber = value;
      if (dialCode) {
        this.activeDialCode = dialCode;
      }
      this.onInputSearch();
    },
    selectContact(contact) {
      this.localContacts = [];
      this.hasSearched = false;
      this.searchQuery = '';
      this.phoneNumber = '';
      this.$emit('select', contact);
    },
    createQuickContact() {
      this.$emit('create-quick', this.activeQuery);
    },
    async fetchContacts() {
      const query = this.activeQuery;
      const rawLength =
        this.inputMode === 'phone'
          ? this.phoneNumber.replace(/^\+/, '').trim().length
          : this.searchQuery.trim().length;

      if (rawLength < this.minSearchLength) {
        this.localContacts = [];
        this.isLoading = false;
        this.hasSearched = false;
        return;
      }

      this.isLoading = true;
      this.hasSearched = true;

      try {
        this.localContacts = await searchContacts(query);
      } catch (_error) {
        this.localContacts = [];
      } finally {
        this.isLoading = false;
        this.$nextTick(() => {
          this.updateDropdownPosition();
        });
      }
    },
    onInputSearch: debounce(function onInputSearchDebounced() {
      this.fetchContacts();
    }, 400),
    onEnterKey() {
      if (this.localContacts.length === 1) {
        this.selectContact(this.localContacts[0]);
        return;
      }

      if (this.showQuickCreateOption) {
        this.createQuickContact();
      }
    },
  },
};
</script>

<style scoped>
.compose-phone-input ::v-deep .phone-input--wrap > div {
  margin-bottom: 0;
}
</style>
