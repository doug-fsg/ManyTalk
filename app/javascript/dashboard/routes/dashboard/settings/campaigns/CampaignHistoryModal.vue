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
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('CAMPAIGN.HISTORY.CLOSE_BUTTON') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
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
      tableData: this.campaign.audience ? [...this.campaign.audience] : [],
    };
  },
  computed: {
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
          align: 'center',
          sortBy: '',
          renderBodyCell: ({ row }) => {
            return row.status === 'success' ? '✅' : '❌';
          },
        },
      ];
    },
    totalSent() {
      return this.campaign.audience.length;
    },
    successfulCount() {
      return this.campaign.audience.filter(item => item.status === 'success').length;
    },
    failedCount() {
      return this.totalSent - this.successfulCount;
    },
    successPercentage() {
      return (this.successfulCount / this.totalSent) * 100;
    },
    failedPercentage() {
      return (this.failedCount / this.totalSent) * 100;
    },
  },
  watch: {
    'campaign.audience': {
      immediate: true,
      handler(newVal) {
        this.tableData = [...newVal];
      },
    },
  },
  methods: {
    sortChange(params) {
      let data = this.tableData.slice();

      if (params.id) {
        data.sort((a, b) => (params.id === 'asc' ? a.id - b.id : b.id - a.id));
      }

      if (params.status) {
        const statusOrder = { success: 1, failed: 2, error: 2, pending: 3 };
        data.sort((a, b) => {
          const aStatus = statusOrder[a.status] || Number.MAX_SAFE_INTEGER;
          const bStatus = statusOrder[b.status] || Number.MAX_SAFE_INTEGER;
          return params.status === 'asc' ? aStatus - bStatus : bStatus - aStatus;
        });
      }

      this.tableData = data;
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
  border-radius: 10px;
  overflow: hidden;
  margin-top: 15px;
}
.progress-success {
  background-color: #4caf50;
  height: 100%;
}
.progress-fail {
  background-color: #f44336;
  height: 100%;
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
