<template>
  <div class="dashboard-container p-6 bg-slate-50 dark:bg-slate-900">
    <!-- Header -->
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
        {{ $t('KANBAN.DASHBOARD.TITLE') }}
      </h2>
      <p class="text-slate-600 dark:text-slate-400">
        {{ pipelineName }}
      </p>
    </div>

    <!-- Resumo principal -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <!-- Total de Cards -->
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <div class="flex items-center justify-between mb-2">
          <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400">
            {{ $t('KANBAN.DASHBOARD.TOTAL_CARDS') }}
          </h3>
          <fluent-icon icon="contact-card" size="20" class="text-blue-500" />
        </div>
        <p class="text-3xl font-bold text-slate-900 dark:text-white">{{ stats.totalCards }}</p>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ formatCurrency(stats.totalValue) }}
        </p>
      </div>

      <!-- Cards Abertos -->
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <div class="flex items-center justify-between mb-2">
          <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400">
            {{ $t('KANBAN.DASHBOARD.OPEN_CARDS') }}
          </h3>
          <fluent-icon icon="clock" size="20" class="text-indigo-500" />
        </div>
        <p class="text-3xl font-bold text-slate-900 dark:text-white">{{ stats.openCards }}</p>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ formatCurrency(stats.openValue) }}
        </p>
      </div>

      <!-- Cards Ganhos -->
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <div class="flex items-center justify-between mb-2">
          <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400">
            {{ $t('KANBAN.DASHBOARD.WON_CARDS') }}
          </h3>
          <fluent-icon icon="checkmark-circle" size="20" class="text-green-500" />
        </div>
        <p class="text-3xl font-bold text-green-600 dark:text-green-400">{{ stats.wonCards }}</p>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ formatCurrency(stats.wonValue) }}
        </p>
      </div>

      <!-- Cards Perdidos -->
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <div class="flex items-center justify-between mb-2">
          <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400">
            {{ $t('KANBAN.DASHBOARD.LOST_CARDS') }}
          </h3>
          <fluent-icon icon="dismiss-circle" size="20" class="text-red-500" />
        </div>
        <p class="text-3xl font-bold text-red-600 dark:text-red-400">{{ stats.lostCards }}</p>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ formatCurrency(stats.lostValue) }}
        </p>
      </div>
    </div>

    <!-- Taxa de Conversão -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400 mb-2">
          {{ $t('KANBAN.DASHBOARD.WIN_RATE') }}
        </h3>
        <p class="text-3xl font-bold text-slate-900 dark:text-white">{{ stats.winRate }}%</p>
      </div>

      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400 mb-2">
          {{ $t('KANBAN.DASHBOARD.AVERAGE_TIME') }}
        </h3>
        <p class="text-3xl font-bold text-slate-900 dark:text-white">{{ stats.averageTime }}</p>
      </div>

      <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700">
        <h3 class="text-sm font-medium text-slate-600 dark:text-slate-400 mb-2">
          {{ $t('KANBAN.DASHBOARD.AVERAGE_DEAL_VALUE') }}
        </h3>
        <p class="text-3xl font-bold text-slate-900 dark:text-white">
          {{ formatCurrency(stats.averageDealValue) }}
        </p>
      </div>
    </div>

    <!-- Cards por Estágio -->
    <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700 mb-6">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        {{ $t('KANBAN.DASHBOARD.BY_STAGE') }}
      </h3>
      <div v-if="stageStats.length === 0" class="text-center text-slate-500 dark:text-slate-400 py-8">
        {{ $t('KANBAN.DASHBOARD.NO_STAGE_DATA') }}
      </div>
      <div v-else class="space-y-4">
        <div
          v-for="(stage, index) in stageStats"
          :key="`stage-${stage.name}-${stage.percentage}-${index}`"
          class="flex items-center justify-between p-4 bg-slate-50 dark:bg-slate-700/50 rounded-lg"
        >
          <div class="flex-1">
            <div class="flex items-center justify-between mb-2">
              <span class="font-medium text-slate-900 dark:text-white">{{ stage.name }}</span>
              <span class="text-sm text-slate-600 dark:text-slate-400">
                {{ stage.count }} {{ stage.count === 1 ? $t('KANBAN.DASHBOARD.ITEM') : $t('KANBAN.DASHBOARD.ITEMS') }} • {{ formatCurrency(stage.value) }}
              </span>
            </div>
            <div 
              class="w-full rounded-full relative" 
              style="height: 8px; overflow: hidden; position: relative; background-color: rgb(226 232 240);"
            >
              <div
                class="rounded-full transition-all duration-300"
                :style="{ 
                  width: `${Math.max(stage.percentage, 0)}%`,
                  height: '8px',
                  minWidth: stage.count > 0 ? '2px' : '0px',
                  display: 'block',
                  position: 'absolute',
                  top: '0',
                  left: '0',
                  backgroundColor: '#3b82f6'
                }"
                :title="`${stage.percentage.toFixed(1)}%`"
              ></div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Cards com mais tempo na etapa -->
    <div class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700 mb-6">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        {{ $t('KANBAN.DASHBOARD.LONGEST_IN_STAGE') }}
      </h3>
      <div class="space-y-3">
        <div
          v-for="card in longestInStage"
          :key="card.id"
          class="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 cursor-pointer transition-colors"
          @click="$emit('view-contact', card.id)"
        >
          <div class="flex-1">
            <p class="font-medium text-slate-900 dark:text-white">{{ card.name }}</p>
            <p class="text-sm text-slate-600 dark:text-slate-400">{{ card.stage }}</p>
          </div>
          <div class="text-right">
            <p class="text-sm font-medium text-slate-900 dark:text-white">{{ card.timeInStage }}</p>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ formatCurrency(card.value) }}
            </p>
          </div>
        </div>
        <p v-if="!longestInStage.length" class="text-center text-slate-500 dark:text-slate-400 py-4">
          {{ $t('KANBAN.DASHBOARD.NO_CARDS') }}
        </p>
      </div>
    </div>

    <!-- Top Responsáveis (se houver dados) -->
    <div 
      v-if="topAssignees.length"
      class="bg-white dark:bg-slate-800 rounded-lg shadow-sm p-6 border border-slate-200 dark:border-slate-700"
    >
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        {{ $t('KANBAN.DASHBOARD.TOP_ASSIGNEES') }}
      </h3>
      <div class="space-y-3">
        <div
          v-for="assignee in topAssignees"
          :key="assignee.id"
          class="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg"
        >
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-blue-500 flex items-center justify-center text-white font-semibold">
              {{ assignee.initials }}
            </div>
            <div>
              <p class="font-medium text-slate-900 dark:text-white">{{ assignee.name }}</p>
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {{ assignee.count }} {{ assignee.count === 1 ? $t('KANBAN.DASHBOARD.ITEM') : $t('KANBAN.DASHBOARD.ITEMS') }}
              </p>
            </div>
          </div>
          <p class="font-medium text-slate-900 dark:text-white">
            {{ formatCurrency(assignee.value) }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import ContactAPI from 'dashboard/api/contacts';
import {
  getStage,
  getDealValue,
  getMetadata,
  getWinLostStatus,
  getEnteredAt,
} from '../utils/pipelinePositionsHelper';

export default {
  name: 'KanbanDashboard',
  props: {
    contacts: {
      type: Array,
      default: () => [],
    },
    columns: {
      type: Array,
      default: () => [],
    },
    pipelineId: {
      type: [Number, String],
      required: true,
    },
    pipelineName: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      backendStats: null, // Estatísticas do backend (usado apenas quando não há filtros)
      isLoading: false,
    };
  },
  watch: {
    pipelineId: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          // Buscar do backend apenas quando não temos contatos carregados ainda
          // Quando temos contatos (filtrados ou não), calcular baseado neles
          if (this.contacts.length === 0) {
            this.fetchDashboardStats();
          }
        }
      },
    },
    contacts: {
      handler() {
        // Quando os contatos filtrados mudam, recalcular estatísticas
        // Se temos contatos, sempre calcular baseado neles (ignorar backend)
        if (this.contacts.length > 0) {
          this.backendStats = null; // Forçar recalcular usando contacts filtrados
        }
      },
      deep: true,
    },
  },
  computed: {
    // Calcular estatísticas baseadas nos contatos filtrados
    stats() {
      // Se temos contatos carregados, sempre calcular baseado neles (respeita filtros)
      if (this.contacts.length > 0) {
        return this.calculateStatsFromContacts();
      }

      // Se não temos contatos ainda, usar estatísticas do backend (loading state)
      if (this.backendStats) {
        return {
          totalCards: this.backendStats.total_cards || 0,
          totalValue: this.backendStats.total_value || 0,
          openCards: this.backendStats.open_cards || 0,
          openValue: this.backendStats.open_value || 0,
          wonCards: this.backendStats.won_cards || 0,
          wonValue: this.backendStats.won_value || 0,
          lostCards: this.backendStats.lost_cards || 0,
          lostValue: this.backendStats.lost_value || 0,
          winRate: this.backendStats.win_rate || 0,
          averageTime: `${this.backendStats.average_time_days || 0}d`,
          averageDealValue: this.backendStats.average_deal_value || 0,
        };
      }

      // Sem dados ainda
      return {
        totalCards: 0,
        totalValue: 0,
        openCards: 0,
        openValue: 0,
        wonCards: 0,
        wonValue: 0,
        lostCards: 0,
        lostValue: 0,
        winRate: 0,
        averageTime: '0d',
        averageDealValue: 0,
      };
    },
    stageStats() {
      // Se temos contatos carregados, sempre calcular baseado neles (respeita filtros)
      if (this.contacts.length > 0) {
        return this.calculateStageStatsFromContacts();
      }

      // Se não temos contatos ainda, usar estatísticas do backend
      if (this.backendStats && this.backendStats.stage_stats) {
        const totalCount = this.backendStats.total_cards || 0;
        
        // Mapear stage_stats do backend para o formato esperado pelo template
        return this.backendStats.stage_stats.map(stat => {
          const percentage = totalCount > 0 ? (stat.count / totalCount) * 100 : 0;
          const minPercentage = stat.count > 0 && percentage < 1 ? 1 : percentage;
          
          // Encontrar o nome do stage a partir das colunas
          const column = this.columns.find(col => col.title === stat.stage_id);
          const stageName = column ? column.title : stat.stage_id;
          
          return {
            name: stageName,
            count: stat.count,
            value: stat.total_value,
            percentage: minPercentage,
          };
        });
      }

      return [];
    },
    longestInStage() {
      // Se temos contatos carregados, sempre calcular baseado neles (respeita filtros)
      if (this.contacts.length > 0) {
        return this.calculateLongestInStageFromContacts();
      }

      // Se não temos contatos ainda, usar estatísticas do backend
      if (this.backendStats && this.backendStats.longest_in_stage) {
        // Mapear os dados do backend para o formato esperado pelo template
        return this.backendStats.longest_in_stage.map(item => {
          // Encontrar o nome do stage
          const column = this.columns.find(col => col.title === item.stage_id);
          const stageName = column ? column.title : item.stage_id;
          
          return {
            id: item.contact_id,
            name: item.name,
            stage: stageName,
            timeInStage: `${item.time_in_stage_days}d`,
            timeDiffMs: item.time_in_stage_days * 86400000, // Para ordenação
            value: item.deal_value,
          };
        });
      }

      return [];
    },
    topAssignees() {
      // Placeholder - implementar quando houver dados de responsável
      return [];
    },
  },
  methods: {
    // Calcular estatísticas gerais baseadas nos contatos filtrados
    calculateStatsFromContacts() {
      if (!this.contacts || this.contacts.length === 0) {
        return {
          totalCards: 0,
          totalValue: 0,
          openCards: 0,
          openValue: 0,
          wonCards: 0,
          wonValue: 0,
          lostCards: 0,
          lostValue: 0,
          winRate: 0,
          averageTime: '0d',
          averageDealValue: 0,
        };
      }

      const pipelineId = typeof this.pipelineId === 'string' ? parseInt(this.pipelineId, 10) : this.pipelineId;
      let totalValue = 0;
      let wonCards = 0;
      let lostCards = 0;
      let wonValue = 0;
      let lostValue = 0;
      let totalTimeMs = 0;
      let cardsWithTime = 0;
      let cardsWithValue = 0;
      let totalDealValue = 0;

      this.contacts.forEach(contact => {
        const dealValue = getDealValue(contact, pipelineId) || 0;
        totalValue += parseFloat(dealValue);

        const winLostData = getWinLostStatus(contact, pipelineId);
        const status = winLostData?.status;

        if (status === 'won') {
          wonCards++;
          wonValue += parseFloat(dealValue);
        } else if (status === 'lost') {
          lostCards++;
          lostValue += parseFloat(dealValue);
        }

        // Calcular tempo médio
        const enteredAt = getEnteredAt(contact, pipelineId);
        if (enteredAt) {
          const enteredDate = new Date(enteredAt);
          const now = new Date();
          const timeDiff = now - enteredDate;
          totalTimeMs += timeDiff;
          cardsWithTime++;
        }

        // Calcular valor médio
        if (dealValue > 0) {
          totalDealValue += parseFloat(dealValue);
          cardsWithValue++;
        }
      });

      const openCards = this.contacts.length - wonCards - lostCards;
      const openValue = totalValue - wonValue - lostValue;
      const totalFinalized = wonCards + lostCards;
      const winRate = totalFinalized > 0 ? Math.round((wonCards / totalFinalized) * 100) : 0;
      const averageTimeDays = cardsWithTime > 0 ? Math.round(totalTimeMs / cardsWithTime / (1000 * 60 * 60 * 24)) : 0;
      const averageDealValue = cardsWithValue > 0 ? totalDealValue / cardsWithValue : 0;

      return {
        totalCards: this.contacts.length,
        totalValue,
        openCards,
        openValue,
        wonCards,
        wonValue,
        lostCards,
        lostValue,
        winRate,
        averageTime: `${averageTimeDays}d`,
        averageDealValue,
      };
    },
    // Calcular estatísticas por stage baseadas nos contatos filtrados
    calculateStageStatsFromContacts() {
      if (!this.contacts || this.contacts.length === 0) {
        return [];
      }

      const pipelineId = typeof this.pipelineId === 'string' ? parseInt(this.pipelineId, 10) : this.pipelineId;
      const stageMap = {};

      this.contacts.forEach(contact => {
        const stageId = getStage(contact, pipelineId);
        if (!stageId) return;

        if (!stageMap[stageId]) {
          stageMap[stageId] = {
            stage_id: stageId,
            count: 0,
            total_value: 0,
          };
        }

        stageMap[stageId].count++;
        const dealValue = getDealValue(contact, pipelineId) || 0;
        stageMap[stageId].total_value += parseFloat(dealValue);
      });

      const totalCount = this.contacts.length;
      return Object.values(stageMap).map(stat => {
        const percentage = totalCount > 0 ? (stat.count / totalCount) * 100 : 0;
        const minPercentage = stat.count > 0 && percentage < 1 ? 1 : percentage;
        
        const column = this.columns.find(col => col.title === stat.stage_id);
        const stageName = column ? column.title : stat.stage_id;
        
        return {
          name: stageName,
          count: stat.count,
          value: stat.total_value,
          percentage: minPercentage,
        };
      });
    },
    // Calcular cards com mais tempo na etapa baseado nos contatos filtrados
    calculateLongestInStageFromContacts() {
      if (!this.contacts || this.contacts.length === 0) {
        return [];
      }

      const pipelineId = typeof this.pipelineId === 'string' ? parseInt(this.pipelineId, 10) : this.pipelineId;
      const now = new Date();
      
      const cardsWithTime = this.contacts
        .map(contact => {
          const stageId = getStage(contact, pipelineId);
          if (!stageId) return null;

          const enteredAt = getEnteredAt(contact, pipelineId);
          if (!enteredAt) return null;

          const enteredDate = new Date(enteredAt);
          const timeDiffMs = now - enteredDate;
          const timeDiffDays = Math.round(timeDiffMs / (1000 * 60 * 60 * 24));

          const column = this.columns.find(col => col.title === stageId);
          const stageName = column ? column.title : stageId;

          return {
            id: contact.id,
            name: contact.name || '',
            stage: stageName,
            timeInStage: `${timeDiffDays}d`,
            timeDiffMs,
            value: getDealValue(contact, pipelineId) || 0,
          };
        })
        .filter(card => card !== null)
        .sort((a, b) => b.timeDiffMs - a.timeDiffMs)
        .slice(0, 10); // Top 10

      return cardsWithTime;
    },
    async fetchDashboardStats() {
      if (!this.pipelineId) return;
      
      try {
        this.isLoading = true;
        const response = await ContactAPI.getDashboardStats(this.pipelineId);
        this.backendStats = response.data;
      } catch (error) {
        console.error('Erro ao carregar estatísticas do dashboard:', error);
        // Não usar fallback - mostrar erro ou dados vazios
        this.backendStats = {
          total_cards: 0,
          total_value: 0,
          open_cards: 0,
          open_value: 0,
          won_cards: 0,
          won_value: 0,
          lost_cards: 0,
          lost_value: 0,
          win_rate: 0,
          average_time_days: 0,
          average_deal_value: 0,
          stage_stats: []
        };
      } finally {
        this.isLoading = false;
      }
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(value);
    },
    getContactStage(contact) {
      const column = this.columns.find(col =>
        col.items.some(item => item.id === contact.id)
      );
      return column ? column.title : '';
    },
  },
};
</script>

<style scoped>
.dashboard-container {
  animation: fadeIn 0.3s ease-in-out;
  min-height: 100%;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

/* Garantir que a barra de progresso seja visível */
.bg-blue-500 {
  background-color: #3b82f6 !important;
}

.dark .bg-blue-500 {
  background-color: #3b82f6 !important;
}
</style>

