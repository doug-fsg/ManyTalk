<template>
  <form @submit.prevent="onSubmit">
    <div>
      <div
        v-if="!hasEligibleConversations"
        class="p-3 text-sm rounded-md bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200"
      >
        {{ $t('MERGE_CONVERSATIONS.EMPTY_STATE') }}
      </div>
      <div v-else>
        <div
          class="mt-1 multiselect-wrap--medium"
          :class="{ error: $v.parentConversation.$error }"
        >
          <label class="multiselect__label">
            {{ $t('MERGE_CONVERSATIONS.PARENT.TITLE') }}
            <woot-label
              :title="$t('MERGE_CONVERSATIONS.PARENT.HELP_LABEL')"
              color-scheme="success"
              small
              class="ml-2"
            />
          </label>
          <multiselect
            v-model="parentConversation"
            :options="filteredConversations"
            :custom-label="conversationLabel"
            track-by="id"
            :internal-search="false"
            :clear-on-select="false"
            :show-labels="false"
            :placeholder="$t('MERGE_CONVERSATIONS.PARENT.PLACEHOLDER')"
            :allow-empty="true"
            :loading="isLoading"
            :max-height="150"
            open-direction="top"
            @search-change="onSearchChange"
          >
            <template slot="singleLabel" slot-scope="props">
              <conversation-dropdown-item :conversation="props.option" />
            </template>
            <template slot="option" slot-scope="props">
              <conversation-dropdown-item :conversation="props.option" />
            </template>
            <span slot="noResult">
              {{ $t('AGENT_MGMT.SEARCH.NO_RESULTS') }}
            </span>
          </multiselect>
          <span v-if="$v.parentConversation.$error" class="message">
            {{ $t('MERGE_CONVERSATIONS.FORM.PARENT_CONVERSATION.ERROR') }}
          </span>
        </div>
      </div>
      <div class="flex multiselect-wrap--medium">
        <div
          class="w-8 relative text-base text-slate-100 dark:text-slate-600 after:content-[''] after:h-12 after:w-0 after:left-4 after:absolute after:border-l after:border-solid after:border-slate-100 after:dark:border-slate-600 before:content-[''] before:h-0 before:w-4 before:left-4 before:top-12 before:absolute before:border-b before:border-solid before:border-slate-100 before:dark:border-slate-600"
        >
          <fluent-icon
            icon="arrow-up"
            class="absolute -top-1 left-2"
            size="17"
          />
        </div>
        <div class="flex flex-col w-full">
          <label class="multiselect__label">
            {{ $t('MERGE_CONVERSATIONS.PRIMARY.TITLE') }}
            <woot-label
              :title="$t('MERGE_CONVERSATIONS.PRIMARY.HELP_LABEL')"
              color-scheme="alert"
              small
              class="ml-2"
            />
          </label>
          <multiselect
            :value="primaryConversation"
            disabled
            :options="[]"
            :show-labels="false"
            :custom-label="conversationLabel"
            track-by="id"
          >
            <template slot="singleLabel" slot-scope="props">
              <conversation-dropdown-item :conversation="props.option" />
            </template>
          </multiselect>
        </div>
      </div>
    </div>
    <merge-conversation-summary
      :primary-conversation-id="primaryConversation.id"
      :parent-conversation-id="parentConversationId"
    />
    <div class="flex justify-end gap-2 mt-6">
      <woot-button variant="clear" @click.prevent="onCancel">
        {{ $t('MERGE_CONVERSATIONS.FORM.CANCEL') }}
      </woot-button>
      <woot-button
        type="submit"
        :is-loading="isMerging"
        :disabled="!hasEligibleConversations"
      >
        {{ $t('MERGE_CONVERSATIONS.FORM.SUBMIT') }}
      </woot-button>
    </div>
  </form>
</template>

<script>
import { required } from 'vuelidate/lib/validators';
import MergeConversationSummary from './MergeConversationSummary.vue';
import ConversationDropdownItem from './ConversationDropdownItem.vue';

export default {
  components: {
    MergeConversationSummary,
    ConversationDropdownItem,
  },
  props: {
    primaryConversation: {
      type: Object,
      required: true,
    },
    eligibleConversations: {
      type: Array,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
    isMerging: {
      type: Boolean,
      default: false,
    },
  },
  validations: {
    primaryConversation: {
      required,
    },
    parentConversation: {
      required,
    },
  },
  data() {
    return {
      parentConversation: undefined,
      searchQuery: '',
    };
  },
  computed: {
    hasEligibleConversations() {
      return this.eligibleConversations.length > 0;
    },
    filteredConversations() {
      if (!this.searchQuery) {
        return this.eligibleConversations;
      }

      const query = this.searchQuery.toLowerCase();
      return this.eligibleConversations.filter(conversation => {
        const idMatch = String(conversation.id).includes(query);
        const statusMatch = conversation.status?.includes(query);
        const messageMatch = conversation.messages?.[0]?.content
          ?.toLowerCase()
          .includes(query);

        return idMatch || statusMatch || messageMatch;
      });
    },
    parentConversationId() {
      return this.parentConversation ? this.parentConversation.id : '';
    },
  },
  methods: {
    conversationLabel(conversation) {
      return `#${conversation.id}`;
    },
    onSearchChange(query) {
      this.searchQuery = query;
    },
    onSubmit() {
      this.$v.$touch();
      if (this.$v.$invalid || !this.hasEligibleConversations) {
        return;
      }
      this.$emit('submit', this.parentConversation.id);
    },
    onCancel() {
      this.$emit('cancel');
    },
  },
};
</script>

<style lang="scss" scoped>
.error .message {
  @apply mt-0;
}

::v-deep {
  .multiselect {
    @apply rounded-md;
  }

  .multiselect--disabled {
    @apply border-0;

    .multiselect__tags {
      @apply border;
    }
  }

  .multiselect__tags {
    @apply h-auto;
  }

  .multiselect__select {
    @apply mt-px mr-1;
  }
}
</style>
