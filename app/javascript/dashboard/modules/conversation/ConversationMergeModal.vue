<template>
  <woot-modal :show.sync="show" :on-close="onClose">
    <woot-modal-header
      :header-title="$t('MERGE_CONVERSATIONS.TITLE')"
      :header-content="$t('MERGE_CONVERSATIONS.DESCRIPTION')"
    />

    <merge-conversation
      :primary-conversation="primaryConversation"
      :eligible-conversations="eligibleConversations"
      :is-loading="isLoading"
      :is-merging="isMerging"
      @cancel="onClose"
      @submit="onMergeConversations"
    />
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import MergeConversation from 'dashboard/modules/conversation/components/MergeConversation.vue';
import ContactAPI from 'dashboard/api/contacts';
import AccountActionsAPI from 'dashboard/api/accountActions';
import { CONVERSATION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import types from 'dashboard/store/mutation-types';

export default {
  components: { MergeConversation },
  props: {
    primaryConversation: {
      type: Object,
      required: true,
    },
    show: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      isMerging: false,
      eligibleConversations: [],
    };
  },
  computed: {
    ...mapGetters({
      currentAccountId: 'getCurrentAccountId',
      currentChat: 'getSelectedChat',
    }),
    contactId() {
      return this.primaryConversation.meta?.sender?.id;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(value) {
        if (value) {
          this.loadEligibleConversations();
        }
      },
    },
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    async loadEligibleConversations() {
      if (!this.contactId) {
        this.eligibleConversations = [];
        return;
      }

      this.isLoading = true;
      this.eligibleConversations = [];

      try {
        const response = await ContactAPI.getConversations(this.contactId);
        this.eligibleConversations = (response.data.payload || []).filter(
          conversation =>
            conversation.inbox_id === this.primaryConversation.inbox_id &&
            conversation.id !== this.primaryConversation.id
        );
      } catch (error) {
        useAlert(this.$t('MERGE_CONVERSATIONS.FORM.ERROR_MESSAGE'));
      } finally {
        this.isLoading = false;
      }
    },
    async onMergeConversations(parentConversationId) {
      this.$track(CONVERSATION_EVENTS.MERGED_CONVERSATIONS);
      this.isMerging = true;

      try {
        const response = await AccountActionsAPI.mergeConversation(
          parentConversationId,
          this.primaryConversation.id
        );

        this.$store.commit(`conversations/${types.REMOVE_CONVERSATION}`, {
          conversationId: this.primaryConversation.id,
        });
        this.$store.commit(`conversations/${types.UPDATE_CONVERSATION}`, response.data);
        this.$store.dispatch('getConversation', parentConversationId);

        useAlert(this.$t('MERGE_CONVERSATIONS.FORM.SUCCESS_MESSAGE'));
        this.onClose();

        const redirectURL = frontendURL(
          conversationUrl({
            accountId: this.currentAccountId,
            id: parentConversationId,
          })
        );
        this.$router.push({ path: redirectURL });
      } catch (error) {
        useAlert(this.$t('MERGE_CONVERSATIONS.FORM.ERROR_MESSAGE'));
      } finally {
        this.isMerging = false;
      }
    },
  },
};
</script>
