<template>
  <woot-modal :show.sync="show" :on-close="onClose">
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header
        header-title="Relatório da Campanha"
        :header-content="campaign.title"
      />
      <div class="p-6">
        <!-- Progress Bar Section -->
        <div class="mb-4">
          <div class="flex items-center justify-between mb-2">
            <h4 class="text-sm font-medium text-slate-800 dark:text-slate-100">
              Progresso
            </h4>
            <div class="text-xs text-slate-500 dark:text-slate-400 flex items-center">
              <span v-if="isProcessing" class="flex items-center text-woot-500 font-semibold mr-3">
                <span class="w-1.5 h-1.5 rounded-full bg-woot-500 animate-pulse mr-1"></span>
                Processando...
              </span>
              {{ totalDispatched }} / {{ totalContacts }} contatos
            </div>
          </div>
          <div class="w-full bg-slate-100 dark:bg-slate-700 h-2 rounded-full overflow-hidden">
            <div 
              class="bg-woot-500 h-full transition-all duration-300" 
              :style="{ width: `${progressPercentage}%` }"
            ></div>
          </div>
          
          <div class="flex items-center mt-4 space-x-6">
            <div class="text-sm flex items-center text-slate-700 dark:text-slate-200">
              <span class="inline-block w-2 h-2 rounded-full bg-green-500 mr-2"></span>
              Enviados: <b class="ml-1">{{ successCount }}</b>
            </div>
            <div class="text-sm flex items-center text-slate-700 dark:text-slate-200">
              <span class="inline-block w-2 h-2 rounded-full bg-red-500 mr-2"></span>
              Falhas: <b class="ml-1">{{ failureCount }}</b>
            </div>
          </div>
        </div>

        <!-- Contacts Table -->
        <div class="mt-6 border border-slate-200 dark:border-slate-700 rounded-md overflow-x-auto bg-white dark:bg-slate-900">
          <table v-if="reversedTableData.length" class="w-full text-left min-w-[500px]">
            <thead>
              <tr class="bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide">
                <th class="py-3 px-4">Telefone</th>
                <th class="py-3 px-4 text-center">Status</th>
                <th class="py-3 px-4">Detalhes</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="row in reversedTableData" 
                :key="row.id"
                class="border-b border-slate-100 dark:border-slate-800 last:border-b-0 text-sm transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/50"
              >
                <td class="py-3 px-4 font-medium text-slate-800 dark:text-slate-100">{{ row.phone_number }}</td>
                <td class="py-3 px-4 text-center">
                  <span 
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
                    :class="(row.status === 'success' || row.status === 'sent') ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'"
                  >
                    {{ (row.status === 'success' || row.status === 'sent') ? 'Enviado' : 'Falha' }}
                  </span>
                </td>
                <td class="py-3 px-4 text-slate-500 dark:text-slate-400 text-xs truncate max-w-[200px]" :title="row.error_message">
                  <span v-if="row.error_message" class="text-red-600 dark:text-red-400">{{ row.error_message }}</span>
                  <span v-else>--</span>
                </td>
              </tr>
            </tbody>
          </table>
          <div v-else class="flex flex-col items-center py-12 px-6 text-center">
            <svg class="w-10 h-10 text-slate-300 dark:text-slate-600 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">Nenhum processamento registrado</span>
            <span class="text-xs text-slate-400 dark:text-slate-500 mt-1">Os contatos aparecerão aqui em breve...</span>
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapActions, mapGetters } from 'vuex';

export default {
  props: {
    campaign: {
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
      fetchInterval: null,
    };
  },
  computed: {
    ...mapGetters({
      getCampaignProgress: 'campaigns/getCampaignProgress',
    }),
    progressData() {
      return this.getCampaignProgress(this.campaign.id) || {};
    },
    historyLogs() {
      // O backend entrega failed_contacts e successful_contacts separados
      const failed = this.progressData.failed_contacts || this.campaign.trigger_rules?.failed_contacts || [];
      const successful = this.progressData.successful_contacts || this.campaign.trigger_rules?.successful_contacts || [];
      
      const failedLogs = failed.map(c => ({ ...c, status: 'failed' }));
      const successLogs = successful.map(c => ({ ...c, status: 'success' }));
      
      return [...successLogs, ...failedLogs];
    },
    reversedTableData() {
      // O objeto de log nativo possui a prop 'contact' aninhada com os dados originais do import.
      return [...this.historyLogs].reverse().map((log, index) => {
        const c = log.contact || {};
        
        return {
          id: log.id || `log-${index}`,
          phone_number: c.numero || c.phone_number || c.id || '--',
          status: log.status,
          error_message: log.error_message || log.error || '',
        };
      });
    },
    isProcessing() {
      return (this.progressData.status || this.campaign.campaign_status) === 'processing';
    },
    totalContacts() {
      return this.progressData.total || this.campaign.trigger_rules?.delivery_stats?.total || this.campaign.audience?.length || 0;
    },
    successCount() {
      return this.progressData.sent || this.campaign.trigger_rules?.delivery_stats?.sent || 0;
    },
    failureCount() {
      return this.progressData.failed || this.campaign.trigger_rules?.delivery_stats?.failed || 0;
    },
    totalDispatched() {
      return this.successCount + this.failureCount;
    },
    progressPercentage() {
      if (!this.totalContacts) return 0;
      return Math.round((this.totalDispatched / this.totalContacts) * 100);
    },
  },
  watch: {
    show: {
      handler(val) {
        if (val) {
          this.startPolling();
        } else {
          this.stopPolling();
        }
      },
      immediate: true,
    },
    isProcessing(val) {
      if (val && this.show) {
        this.startPolling();
      } else if (!val) {
        if (this.show) {
          this.fetchProgressMethod();
        }
        this.stopPolling();
      }
    }
  },
  mounted() {
    if (this.show) {
      this.fetchProgressMethod();
      this.startPolling();
    }
  },
  destroyed() {
    this.stopPolling();
  },
  methods: {
    ...mapActions('campaigns', ['fetchProgress']),
    onClose() {
      this.$emit('update:show', false);
      this.$emit('on-close');
    },
    async fetchProgressMethod() {
      if (this.campaign?.id) {
        try {
          await this.fetchProgress(this.campaign.id);
        } catch (error) {
          // Ignora silenciosamente para não floodar console do usuário em polling
        }
      }
    },
    startPolling() {
      this.stopPolling();
      this.fetchProgressMethod(); // sync imediato
      if (this.isProcessing) {
        this.fetchInterval = setInterval(() => {
          this.fetchProgressMethod();
        }, 3000); // Poll a cada 3 segundos
      }
    },
    stopPolling() {
      if (this.fetchInterval) {
        clearInterval(this.fetchInterval);
        this.fetchInterval = null;
      }
    },
  },
};
</script>

<style scoped lang="scss">
</style>
