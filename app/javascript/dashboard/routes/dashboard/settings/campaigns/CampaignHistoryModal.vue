<template>
  <woot-modal :show="show" :on-close="onClose">
    <div class="campaign-history-modal">
      <div class="modal-header">
        <h2 class="modal-title">
          {{ $t('CAMPAIGN.HISTORY.TITLE', { campaignTitle: campaign.title }) }}
        </h2>
      </div>

      <div class="history-summary">
        <p>{{ $t('CAMPAIGN.HISTORY.TOTAL_PROCESSED', { count: totalSent }) }}</p>

        <!-- Barra de progresso -->
        <div class="progress-bar">
          <div
            class="progress-success"
            :style="{ width: successPercentage + '%' }"
            :title="$t('CAMPAIGN.HISTORY.SUCCESSFUL', { count: successfulCount })"
          ></div>
          <div
            class="progress-fail"
            :style="{ width: failedPercentage + '%' }"
            :title="$t('CAMPAIGN.HISTORY.FAILED', { count: failedCount })"
          ></div>
        </div>

        <!-- Legenda da barra de progresso -->
        <div class="progress-legend">
          <span class="legend-item">
            <span class="legend-color success"></span>
            {{ $t('CAMPAIGN.HISTORY.SUCCESSFUL', { count: successfulCount }) }}
          </span>
          <span class="legend-item">
            <span class="legend-color fail"></span>
            {{ $t('CAMPAIGN.HISTORY.FAILED', { count: failedCount }) }}
          </span>
        </div>
      </div>

      <div class="history-details">
        <h3>{{ $t('CAMPAIGN.HISTORY.DETAILS') }}</h3>
        <ve-table
          :columns="columns"
          :table-data="tableData"
          :sort-option="sortOption"
          border-y
          class="w-full"
        ></ve-table>
      </div>

      <div class="modal-footer">
        <woot-button
          v-if="failedContacts.length > 0"
          :is-loading="isRetrying"
          color-scheme="alert"
          class="mr-2"
          @click.prevent="retryAllFailed"
        >
          {{ $t('CAMPAIGN.HISTORY.RETRY_FAILED_BUTTON') }}
        </woot-button>
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('CAMPAIGN.HISTORY.CLOSE_BUTTON') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import 'vue-easytable/libs/theme-default/index.css';

export default {
  components: {
    VeTable,
  },
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
  data() {
    return {
      sortOption: {
        multipleSort: true,
        sortChange: params => {
          this.sortChange(params);
        },
      },
      isRetrying: false,
    };
  },
  computed: {
    ...mapGetters({
      getCampaignProgress: 'campaigns/getCampaignProgress',
    }),
    progress() {
      return this.getCampaignProgress(this.campaign.id) || {};
    },
    deliveryStats() {
      return this.progress.sent !== undefined
        ? { sent: this.progress.sent, failed: this.progress.failed, total: this.progress.total }
        : this.campaign.trigger_rules?.delivery_stats || {};
    },
    successfulContacts() {
      return this.progress.successful_contacts ?? this.campaign.trigger_rules?.successful_contacts ?? [];
    },
    failedContacts() {
      return this.progress.failed_contacts ?? this.campaign.trigger_rules?.failed_contacts ?? [];
    },
    allContacts() {
      const successes = this.successfulContacts.map(item => ({
        ...item,
        _status: 'success',
      }));
      const failures = this.failedContacts.map(item => ({
        ...item,
        _status: 'failed',
      }));
      return [...successes, ...failures];
    },
    tableData() {
      return this.allContacts.map(item => ({
        id: this.contactIdentifier(item),
        status: item._status === 'success' ? this.$t('CAMPAIGN.HISTORY.TABLE.STATUS_SUCCESS') : this.$t('CAMPAIGN.HISTORY.TABLE.STATUS_FAILED'),
        error: item.error || '-',
        raw: item,
      }));
    },
    totalSent() {
      return this.deliveryStats.total || this.campaign.audience?.length || 0;
    },
    successfulCount() {
      return this.deliveryStats.sent || this.campaign.audience?.filter(i => i.status === 'success').length || 0;
    },
    failedCount() {
      return this.deliveryStats.failed || (this.totalSent - this.successfulCount);
    },
    successPercentage() {
      return this.totalSent > 0 ? (this.successfulCount / this.totalSent) * 100 : 0;
    },
    failedPercentage() {
      return this.totalSent > 0 ? (this.failedCount / this.totalSent) * 100 : 0;
    },
    columns() {
      return [
        {
          field: 'id',
          key: 'id',
          title: this.$t('CAMPAIGN.HISTORY.TABLE.NUMBER'),
          align: 'left',
          sortBy: '',
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CAMPAIGN.HISTORY.TABLE.STATUS'),
          align: 'left',
        },
        {
          field: 'error',
          key: 'error',
          title: this.$t('CAMPAIGN.HISTORY.TABLE.ERROR'),
          align: 'left',
        },
      ];
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(visible) {
        if (visible && this.campaign?.id) {
          this.$store.dispatch('campaigns/fetchProgress', this.campaign.id);
        }
      },
    },
  },
  methods: {
    contactIdentifier(item) {
      const c = item.contact || item;
      return c.telefone || c.phone_number || c.phone || c.nome || c.name || c.id || '-';
    },
    async retryAllFailed() {
      if (this.isRetrying) return;
      this.isRetrying = true;
      try {
        await this.$store.dispatch('campaigns/retryFailed', { id: this.campaign.id });
        this.$emit('on-close');
      } catch {
        // Ignore
      } finally {
        this.isRetrying = false;
      }
    },
    sortChange(params) {
      // Sorting handled reactively via computed tableData
    },
    onClose() {
      this.$emit('on-close');
    },
  },
};
</script>

<style scoped>
.campaign-history-modal {
  margin: 2rem;
  animation: fade-in-up 0.3s ease-out;
}
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.modal-title {
  font-size: 1.5rem;
  margin-bottom: 1.5rem;
}
.history-summary {
  margin-bottom: 2rem;
}
.history-details {
  margin-top: 2rem;
}
.modal-footer {
  display: flex;
  justify-content: flex-end;
  margin-top: 2rem;
}
.progress-bar {
  display: flex;
  height: 20px;
  width: 100%;
  background-color: #e0e0e0;
  border-radius: 12px;
  overflow: hidden;
  margin-top: 15px;
  transition: all 0.3s ease-smooth;
}
.progress-success {
  background-color: #4caf50;
  height: 100%;
  transition: width 0.3s ease-smooth;
}
.progress-fail {
  background-color: #f44336;
  height: 100%;
  transition: width 0.3s ease-smooth;
}
.progress-legend {
  display: flex;
  justify-content: space-between;
  margin-top: 10px;
  margin-bottom: 20px;
  font-size: 0.75rem;
}
.legend-item {
  display: flex;
  align-items: center;
}
.legend-color {
  display: inline-block;
  width: 12px;
  height: 12px;
  margin-right: 5px;
  border-radius: 50%;
}
.legend-color.success {
  background-color: #4caf50;
}
.legend-color.fail {
  background-color: #f44336;
}
.legend-tooltip {
  margin-left: 5px;
  color: #1f2937;
}
</style>