<template>
  <div class="flex items-center flex-col">
    <div v-if="isLoading" class="items-center flex text-base justify-center">
      <spinner color-scheme="primary" />
      <span>{{ $t('CAMPAIGN.LIST.LOADING_MESSAGE') }}</span>
    </div>
    <div v-else class="w-full">
      <empty-state v-if="showEmptyResult" :title="emptyMessage" />
      <div v-else class="w-full">
        <campaign-card
          v-for="campaign in campaigns"
          :key="campaign.id"
          :campaign="campaign"
          :is-ongoing-type="isOngoingType"
          @edit="campaign => $emit('edit', campaign)"
          @delete="campaign => $emit('delete', campaign)"
          @show-history="onShowHistory"
          @resend="campaign => $emit('resend', campaign)"
        />
        <div
          v-if="showPagination"
          class="flex justify-center mt-4 py-4"
        >
          <table-footer-pagination
            :current-page="paginationMeta.current_page || 1"
            :total-count="paginationMeta.count || 0"
            :total-pages="paginationMeta.total_pages || 1"
            @page-change="$emit('page-change', $event)"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Spinner from 'shared/components/Spinner.vue';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import TableFooterPagination from 'dashboard/components/widgets/TableFooterPagination.vue';
import campaignMixin from 'shared/mixins/campaignMixin';
import CampaignCard from './CampaignCard.vue';

export default {
  components: {
    EmptyState,
    Spinner,
    CampaignCard,
    TableFooterPagination,
  },

  mixins: [campaignMixin],

  props: {
    campaigns: {
      type: Array,
      default: () => [],
    },
    showEmptyResult: {
      type: Boolean,
      default: false,
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
    paginationMeta: {
      type: Object,
      default: () => ({}),
    },
  },
  computed: {
    showPagination() {
      const { total_pages = 0 } = this.paginationMeta;
      return total_pages > 1;
    },
    currentInboxId() {
      return this.$route.params.inboxId;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.currentInboxId);
    },
    inboxes() {
      if (this.isOngoingType) {
        return this.$store.getters['inboxes/getWebsiteInboxes'];
      }
      return this.$store.getters['inboxes/getTwilioInboxes'];
    },
    emptyMessage() {
      if (this.isOngoingType) {
        return this.inboxes.length
          ? this.$t('CAMPAIGN.ONGOING.404')
          : this.$t('CAMPAIGN.ONGOING.INBOXES_NOT_FOUND');
      }

      return this.inboxes.length
        ? this.$t('CAMPAIGN.ONE_OFF.404')
        : this.$t('CAMPAIGN.ONE_OFF.INBOXES_NOT_FOUND');
    },
    successfulCount() {
      return (campaign) => {
        const stats = campaign.trigger_rules?.delivery_stats || {};
        return stats.sent || 0;
      };
    },
    failedCount() {
      return (campaign) => {
        const stats = campaign.trigger_rules?.delivery_stats || {};
        return stats.failed || 0;
      };
    },
  },

  methods: {
    onShowHistory(campaign) {
      this.$emit('show-history', campaign);
    },
  },
};
</script>

<style lang="scss" scoped>
.campaign-stats {
  margin-top: 0.5rem;
  font-size: 0.875rem;
  color: var(--s-600);
}
</style>