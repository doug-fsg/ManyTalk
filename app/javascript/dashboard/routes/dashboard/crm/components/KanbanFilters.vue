<template>
  <div class="kanban-filters relative" v-on-clickaway="closeFilters">
    <!-- Botão para abrir filtros -->
    <woot-button
      variant="clear"
      color-scheme="secondary"
      class="flex items-center gap-2 text-slate-700 dark:text-slate-200 relative"
      @click.stop="toggleFilters"
    >
      <fluent-icon icon="filter" size="16" />
      <span class="hidden lg:inline text-sm">{{ $t('KANBAN.FILTERS.TITLE') }}</span>
      <span 
        v-if="activeFiltersCount > 0" 
        class="absolute -top-1 -right-1 bg-woot-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center"
      >
        {{ activeFiltersCount }}
      </span>
      <fluent-icon icon="chevron-down" size="12" class="text-slate-500 dark:text-slate-400" />
    </woot-button>

    <!-- Dropdown de filtros -->
    <transition
      enter-active-class="transition ease-out duration-100"
      enter-from-class="transform opacity-0 scale-95"
      enter-to-class="transform opacity-100 scale-100"
      leave-active-class="transition ease-in duration-75"
      leave-from-class="transform opacity-100 scale-100"
      leave-to-class="transform opacity-0 scale-95"
    >
      <div 
        v-if="showFilters" 
        class="absolute left-0 mt-2 w-80 rounded-md shadow-lg bg-white dark:bg-slate-800 ring-1 ring-black ring-opacity-5 z-50 p-4"
      >
        <!-- Labels Filter -->
        <div v-if="availableLabels.length" class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
            {{ $t('KANBAN.FILTERS.LABELS') }}
          </label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="label in availableLabels"
              :key="label.id"
              :class="[
                'px-2 py-1 rounded-md text-xs transition-colors',
                selectedLabels.includes(label.id)
                  ? 'bg-woot-500 text-white'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600'
              ]"
              @click="toggleLabel(label.id)"
            >
              {{ label.title }}
            </button>
          </div>
        </div>

        <!-- Deal Value Filter -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
            {{ $t('KANBAN.FILTERS.DEAL_VALUE') }}
          </label>
          <div class="flex items-center gap-2">
            <input
              v-model.number="dealValueMin"
              type="number"
              :placeholder="$t('KANBAN.FILTERS.MIN_VALUE')"
              class="flex-1 px-2 py-1 text-sm border border-slate-200 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200"
              @input="handleDealValueChange"
            />
            <span class="text-slate-500 dark:text-slate-400">-</span>
            <input
              v-model.number="dealValueMax"
              type="number"
              :placeholder="$t('KANBAN.FILTERS.MAX_VALUE')"
              class="flex-1 px-2 py-1 text-sm border border-slate-200 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200"
              @input="handleDealValueChange"
            />
          </div>
        </div>

        <!-- Date Range Filter -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
            {{ $t('KANBAN.FILTERS.DATE_RANGE') }}
          </label>
          <div class="flex flex-col gap-2">
            <div class="flex flex-col gap-1">
              <span class="text-xs font-medium text-slate-500 dark:text-slate-300">
                {{ $t('KANBAN.FILTERS.FROM_DATE') }}
              </span>
              <input
                v-model="dateFrom"
                type="date"
                :placeholder="$t('KANBAN.FILTERS.FROM_DATE')"
                class="w-full px-2 py-1 text-sm border border-slate-200 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200"
                @change="handleDateChange"
              />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-xs font-medium text-slate-500 dark:text-slate-300">
                {{ $t('KANBAN.FILTERS.TO_DATE') }}
              </span>
              <input
                v-model="dateTo"
                type="date"
                :placeholder="$t('KANBAN.FILTERS.TO_DATE')"
                class="w-full px-2 py-1 text-sm border border-slate-200 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200"
                @change="handleDateChange"
              />
            </div>
          </div>
        </div>

        <!-- Botões de ação -->
        <div class="flex items-center justify-between pt-3 border-t border-slate-200 dark:border-slate-700">
          <button
            @click="clearFilters"
            class="text-xs text-slate-600 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200"
          >
            {{ $t('KANBAN.FILTERS.CLEAR_ALL') }}
          </button>
          <woot-button
            size="small"
            variant="smooth"
            @click="applyFilters"
          >
            {{ $t('KANBAN.FILTERS.APPLY') }}
          </woot-button>
        </div>
      </div>
    </transition>
  </div>
</template>

<script>
import { directive as onClickaway } from 'vue-clickaway';

export default {
  name: 'KanbanFilters',
  directives: {
    onClickaway,
  },
  props: {
    contacts: {
      type: Array,
      default: () => [],
    },
    pipelineId: {
      type: [Number, String],
      default: null,
    },
    filters: {
      type: Object,
      default: () => ({
        labels: [],
        dealValueMin: null,
        dealValueMax: null,
        dateFrom: null,
        dateTo: null,
      }),
    },
  },
  data() {
    return {
      showFilters: false,
      selectedLabels: [],
      dealValueMin: null,
      dealValueMax: null,
      dateFrom: null,
      dateTo: null,
    };
  },
  computed: {
    // Extrair todas as labels únicas dos contatos
    availableLabels() {
      const labelsMap = new Map();
      this.contacts.forEach(contact => {
        const labels = contact.labels || [];
        labels.forEach(label => {
          if (!labelsMap.has(label.id)) {
            labelsMap.set(label.id, label);
          }
        });
      });
      return Array.from(labelsMap.values());
    },
    // Contar filtros ativos
    activeFiltersCount() {
      let count = 0;
      if (this.selectedLabels.length > 0) count++;
      if (this.dealValueMin !== null && this.dealValueMin !== '') count++;
      if (this.dealValueMax !== null && this.dealValueMax !== '') count++;
      if (this.dateFrom) count++;
      if (this.dateTo) count++;
      return count;
    },
  },
  watch: {
    filters: {
      handler(newFilters) {
        this.selectedLabels = newFilters.labels || [];
        this.dealValueMin = newFilters.dealValueMin || null;
        this.dealValueMax = newFilters.dealValueMax || null;
        this.dateFrom = newFilters.dateFrom || null;
        this.dateTo = newFilters.dateTo || null;
      },
      immediate: true,
      deep: true,
    },
    availableLabels(newLabels) {
      if (!newLabels.length && this.selectedLabels.length) {
        this.selectedLabels = [];
        this.emitFilters();
      }
    },
  },
  methods: {
    toggleFilters() {
      this.showFilters = !this.showFilters;
    },
    closeFilters() {
      this.showFilters = false;
    },
    toggleLabel(labelId) {
      const index = this.selectedLabels.indexOf(labelId);
      if (index > -1) {
        this.selectedLabels.splice(index, 1);
      } else {
        this.selectedLabels.push(labelId);
      }
    },
    handleDealValueChange() {
      // Emitir mudanças em tempo real (opcional)
      this.emitFilters();
    },
    handleDateChange() {
      // Emitir mudanças em tempo real (opcional)
      this.emitFilters();
    },
    applyFilters() {
      this.emitFilters();
      this.closeFilters();
    },
    clearFilters() {
      this.selectedLabels = [];
      this.dealValueMin = null;
      this.dealValueMax = null;
      this.dateFrom = null;
      this.dateTo = null;
      this.emitFilters();
    },
    emitFilters() {
      this.$emit('filters-changed', {
        labels: this.selectedLabels,
        dealValueMin: this.dealValueMin,
        dealValueMax: this.dealValueMax,
        dateFrom: this.dateFrom,
        dateTo: this.dateTo,
      });
    },
  },
};
</script>

<style scoped>
.kanban-filters {
  position: relative;
}
</style>

