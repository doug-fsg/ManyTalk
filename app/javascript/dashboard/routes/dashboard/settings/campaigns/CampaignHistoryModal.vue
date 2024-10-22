<template>
  <woot-modal :show="show" :on-close="onClose">
    <div class="campaign-history-modal">
      <div class="modal-header">
        <h2 class="modal-title">
          Histórico da Campanha: {{ campaign.title }}
        </h2>
      </div>

      <div class="history-summary">
        <p>Total de números processados: {{ totalSent }}</p>
        
        <!-- Barra de progresso -->
        <div class="progress-bar">
          <div class="progress-success" :style="{ width: successPercentage + '%' }" :title="'Bem-sucedidos: ' + successfulCount"></div>
          <div class="progress-fail" :style="{ width: failedPercentage + '%' }" :title="'Falharam: ' + failedCount"></div>
        </div>

        <!-- Legenda da barra de progresso -->
        <div class="progress-legend">
          <span class="legend-item">
            <span class="legend-color success"></span> Bem-sucedidos: {{ successfulCount }}
          </span>
          <span class="legend-item">
            <span class="legend-color fail"></span> Falharam: {{ failedCount }}
          </span>
        </div>
      </div>

      <div class="history-details">
        <h3>Detalhes</h3>
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
          Fechar
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { VeTable } from "vue-easytable";
import "vue-easytable/libs/theme-default/index.css";

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
        sortChange: (params) => {
          this.sortChange(params);
        },
      },
      columns: [
        {
          field: "id",
          key: "id",
          title: "Números",
          align: "left",
          sortBy: "",
        },
        {
          field: "status",
          key: "status",
          title: "Status",
          align: "center",
          sortBy: "",
          renderBodyCell: ({ row }) => {
            return row.status === "success" ? "✅" : "❌";
          },
        },
      ],
      tableData: this.campaign.audience ? [...this.campaign.audience] : [],
    };
  },
  computed: {
    totalSent() {
      return this.campaign.audience.length;
    },
    successfulCount() {
      return this.campaign.audience.filter(
        (item) => item.status === "success"
      ).length;
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
    "campaign.audience": {
      immediate: true,
      handler(newVal) {
        this.tableData = [...newVal];
      },
    },
  },
  methods: {
    sortChange(params) {
      let data = this.tableData.slice(0);

      if (params.id) {
        data.sort((a, b) => {
          if (params.id === "asc") {
            return a.id - b.id;
          } else if (params.id === "desc") {
            return b.id - a.id;
          } else {
            return 0;
          }
        });
      }

      if (params.status) {
        data.sort((a, b) => {
          const statusOrder = { success: 1, failed: 2, error: 2, pending: 3 };
          const aStatus = statusOrder[a.status] || Number.MAX_SAFE_INTEGER;
          const bStatus = statusOrder[b.status] || Number.MAX_SAFE_INTEGER;

          if (params.status === "asc") {
            return aStatus - bStatus;
          } else if (params.status === "desc") {
            return bStatus - aStatus;
          } else {
            return 0;
          }
        });
      }

      this.tableData = data;
    },
    onClose() {
      this.$emit("on-close");
    },
  },
};
</script>

<style scoped>
.campaign-history-modal {
  margin: 2rem;  /* Adicionei margens ao redor para mais espaço nas laterais e em cima/baixo */
}
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.modal-title {
  font-size: 1.5rem;
  margin-bottom: 1.5rem; /* Mais espaçamento abaixo do título */
}
.history-summary {
  margin-bottom: 2rem; /* Mais espaçamento abaixo do sumário */
}
.history-details {
  margin-top: 2rem; /* Mais espaçamento acima dos detalhes */
}
.modal-footer {
  display: flex;
  justify-content: flex-end;
  margin-top: 2rem; /* Mais espaçamento acima do rodapé */
}

/* Estilos da barra de progresso */
.progress-bar {
  display: flex;
  height: 20px;
  width: 100%;
  background-color: #e0e0e0;
  border-radius: 10px;
  overflow: hidden;
  margin-top: 15px; /* Mais espaçamento acima da barra de progresso */
}

.progress-success {
  background-color: #4caf50;
  height: 100%;
}

.progress-fail {
  background-color: #f44336;
  height: 100%;
}

/* Legenda da barra de progresso */
.progress-legend {
  display: flex;
  justify-content: space-between;
  margin-top: 10px; /* Mais espaçamento acima */
  margin-bottom: 20px; /* Mais espaçamento abaixo */
  font-size: 0.750rem; /* Tamanho de texto reduzido */
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
  color: #1f2937; /* Cor do texto padrão do sistema */
}
</style>
