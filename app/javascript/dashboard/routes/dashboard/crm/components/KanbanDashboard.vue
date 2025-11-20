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
  computed: {
    stats() {
      const stats = {
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

      let totalTimeInStage = 0;
      let cardsWithTime = 0;
      let totalDealValue = 0;
      let cardsWithValue = 0;

      this.contacts.forEach(contact => {
        // Usar pipeline_positions em vez de additional_attributes
        const position = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.pipelineId
        );
        
        const winLostData = position?.metadata?.win_lost || {};
        const winLostStatus = winLostData.status;
        const dealValue = parseFloat(position?.deal_value || 0);
        const enteredAt = position?.entered_at;

        stats.totalCards++;
        stats.totalValue += dealValue;

        if (dealValue > 0) {
          totalDealValue += dealValue;
          cardsWithValue++;
        }

        if (winLostStatus === 'won') {
          stats.wonCards++;
          stats.wonValue += dealValue;
        } else if (winLostStatus === 'lost') {
          stats.lostCards++;
          stats.lostValue += dealValue;
        } else {
          stats.openCards++;
          stats.openValue += dealValue;
        }

        // Calcular tempo médio na etapa usando pipeline_positions
        if (enteredAt) {
          const enteredAtTime = new Date(enteredAt).getTime();
          const now = Date.now();
          const timeDiff = now - enteredAtTime;
          totalTimeInStage += timeDiff;
          cardsWithTime++;
        }
      });

      // Taxa de conversão
      const totalFinalized = stats.wonCards + stats.lostCards;
      if (totalFinalized > 0) {
        stats.winRate = Math.round((stats.wonCards / totalFinalized) * 100);
      }

      // Tempo médio
      if (cardsWithTime > 0) {
        const avgTime = totalTimeInStage / cardsWithTime;
        const days = Math.floor(avgTime / 86400000);
        stats.averageTime = `${days}d`;
      }

      // Valor médio
      if (cardsWithValue > 0) {
        stats.averageDealValue = totalDealValue / cardsWithValue;
      }

      return stats;
    },
    stageStats() {
      if (!this.columns || this.columns.length === 0) {
        return [];
      }

      const stageMap = {};
      let totalCount = 0;

      this.columns.forEach(column => {
        if (!column.items || !Array.isArray(column.items)) {
          return;
        }

        const count = column.items.length;
        const value = column.items.reduce((sum, contact) => {
          // Usar pipeline_positions em vez de additional_attributes
          const position = contact.pipeline_positions?.find(
            p => p.pipeline_id === this.pipelineId
          );
          const dealValue = parseFloat(position?.deal_value || 0);
          return sum + dealValue;
        }, 0);

        stageMap[column.title] = { count, value };
        totalCount += count;
      });

      return this.columns.map(column => {
        const stage = stageMap[column.title] || { count: 0, value: 0 };
        const percentage = totalCount > 0 ? (stage.count / totalCount) * 100 : 0;
        
        const minPercentage = stage.count > 0 && percentage < 1 ? 1 : percentage;
        
        return {
          name: column.title,
          count: stage.count,
          value: stage.value,
          percentage: minPercentage,
        };
      });
    },
    longestInStage() {
      const cards = [];

      this.contacts.forEach(contact => {
        // Usar pipeline_positions em vez de additional_attributes.kanban
        const position = contact.pipeline_positions?.find(
          p => p.pipeline_id === this.pipelineId
        );
        
        if (!position) return;

        const winLostData = position.metadata?.win_lost || {};
        const winLostStatus = winLostData.status;

        // Apenas cards abertos
        if (winLostStatus) return;

        const enteredAt = position.entered_at;
        if (enteredAt) {
          const enteredAtTime = new Date(enteredAt).getTime();
          const now = Date.now();
          const timeDiff = now - enteredAtTime;
          const days = Math.floor(timeDiff / 86400000);

          cards.push({
            id: contact.id,
            name: contact.name,
            stage: this.getContactStage(contact),
            timeInStage: `${days}d`,
            timeDiffMs: timeDiff,
            value: parseFloat(position.deal_value || 0),
          });
        }
      });

      // Ordenar por tempo decrescente e pegar top 5
      return cards.sort((a, b) => b.timeDiffMs - a.timeDiffMs).slice(0, 5);
    },
    topAssignees() {
      // Placeholder - implementar quando houver dados de responsável
      return [];
    },
  },
  methods: {
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

