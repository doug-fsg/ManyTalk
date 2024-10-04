<template>
  <woot-modal :show="show" @close="onClose">
    <div class="campaign-history-modal">
      <h2 class="modal-title">
        {{ $t('CAMPAIGN.HISTORY.TITLE', { campaignTitle: campaign.title }) }}
      </h2>
      <div class="history-summary">
        <p>
          {{ $t('CAMPAIGN.HISTORY.TOTAL_SENT', { count: totalSent }) }}
        </p>
        <p>
          {{ $t('CAMPAIGN.HISTORY.SUCCESSFUL', { count: successfulCount }) }}
        </p>
        <p>
          {{ $t('CAMPAIGN.HISTORY.FAILED', { count: failedCount }) }}
        </p>
      </div>
      <div class="history-details">
        <h3>{{ $t('CAMPAIGN.HISTORY.DETAILS') }}</h3>
        <ul>
          <li v-for="(item, index) in sortedAudience" :key="index">
            {{ item.id }} {{ item.status === 'success' ? '✅' : '❌' }}
          </li>
        </ul>
      </div>
    </div>
  </woot-modal>
</template>

<script>
export default {
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    campaign: {
      type: Object,
      required: true,
    },
  },
  computed: {
    sortedAudience() {
      return [...this.campaign.audience].sort((a, b) => {
        if (a.status === 'failed' && b.status !== 'failed') return -1;
        if (a.status !== 'failed' && b.status === 'failed') return 1;
        return 0;
      });
    },
    totalSent() {
      return this.campaign.audience.length;
    },
    successfulCount() {
      return this.campaign.audience.filter(item => item.status === 'success')
        .length;
    },
    failedCount() {
      return this.totalSent - this.successfulCount;
    },
  },
  methods: {
    onClose() {
      this.$emit('update:show', false);
    },
  },
};
</script>

<style scoped>
.campaign-history-modal {
  padding: 1rem;
}
.modal-title {
  font-size: 1.5rem;
  margin-bottom: 1rem;
}
.history-summary {
  margin-bottom: 1rem;
}
.history-details ul {
  max-height: 300px;
  overflow-y: auto;
  list-style-type: none;
  padding-left: 0;
}

.history-details li {
  margin-bottom: 5px;
}
</style>
