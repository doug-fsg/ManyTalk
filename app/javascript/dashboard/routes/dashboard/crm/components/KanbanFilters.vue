<template>
  <div class="kanban-filters relative" v-on-clickaway="closeFilters">
    <!-- Botão para abrir filtros -->
    <button
      @click.stop="toggleFilters"
      :class="[
        'relative inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
        'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
        'hover:bg-slate-50 dark:hover:bg-slate-700',
        activeFiltersCount > 0 ? 'bg-slate-50 dark:bg-slate-800/50 text-slate-700 dark:text-slate-200' : '',
        showFilters ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100' : ''
      ]"
    >
      <fluent-icon icon="filter" size="14" />
      <span class="hidden lg:inline">{{ $t('KANBAN.FILTERS.TITLE') }}</span>
      <fluent-icon 
        icon="chevron-down" 
        size="10" 
        :class="[
          'transition-transform duration-200',
          showFilters ? 'rotate-180' : ''
        ]"
      />
      <span 
        v-if="activeFiltersCount > 0" 
        class="absolute -top-1 -right-1 bg-woot-500 text-white text-[10px] font-semibold rounded-full min-w-[16px] h-4 px-1 flex items-center justify-center leading-none"
      >
        {{ activeFiltersCount }}
      </span>
    </button>

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
        class="absolute left-0 mt-2 w-96 rounded-xl shadow-soft-xl bg-white dark:bg-slate-800 ring-1 ring-black ring-opacity-5 z-50 p-4 animate-scale-in"
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
                'px-2 py-1 rounded-lg text-xs transition-colors duration-150 ease-smooth',
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
              class="flex-1 px-2 py-1 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
              @input="handleDealValueChange"
            />
            <span class="text-slate-500 dark:text-slate-400 text-xs">-</span>
            <input
              v-model.number="dealValueMax"
              type="number"
              :placeholder="$t('KANBAN.FILTERS.MAX_VALUE')"
              class="flex-1 px-2 py-1 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
              @input="handleDealValueChange"
            />
          </div>
        </div>

        <!-- Date Range Filter -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
            {{ $t('KANBAN.FILTERS.DATE_RANGE') }}
          </label>
          <div class="flex items-center gap-2">
            <input
              v-model="dateFrom"
              type="date"
              :placeholder="$t('KANBAN.FILTERS.FROM_DATE')"
              class="flex-1 px-2 py-1 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
              @change="handleDateChange"
            />
            <span class="text-slate-500 dark:text-slate-400 text-xs">-</span>
            <input
              v-model="dateTo"
              type="date"
              :placeholder="$t('KANBAN.FILTERS.TO_DATE')"
              class="flex-1 px-2 py-1 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 transition-colors duration-150 ease-smooth"
              @change="handleDateChange"
            />
          </div>
        </div>

        <!-- Win/Lost Filter -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
            {{ $t('KANBAN.FILTERS.STATUS') }}
          </label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="option in statusOptions"
              :key="option.value"
              :class="[
                'px-2 py-1 rounded-md text-xs transition-colors flex items-center gap-1',
                winLostFilter === option.value
                  ? 'bg-woot-500 text-white'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600'
              ]"
              @click="setWinLostFilter(option.value)"
            >
              <fluent-icon :icon="option.icon" size="12" />
              {{ option.label }}
            </button>
          </div>
        </div>

        <!-- Assignee Filter (apenas para admin/supervisor) -->
        <div v-if="showAssigneeFilter" class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
            {{ $t('KANBAN.FILTERS.ASSIGNEE') }}
          </label>
          <multiselect
            v-model="selectedAssignees"
            :options="assigneeOptions"
            track-by="id"
            label="name"
            :multiple="true"
            :close-on-select="false"
            :clear-on-select="false"
            :hide-selected="true"
            :placeholder="$t('KANBAN.FILTERS.ASSIGNEE_PLACEHOLDER')"
            selected-label
            :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
            :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
            @input="handleAssigneeChange"
          />
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
import { mapGetters } from 'vuex';

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
        assignees: [],
        winLost: 'all',
      }),
    },
    showAssigneeFilter: {
      type: Boolean,
      default: false,
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
      selectedAssignees: [],
      winLostFilter: 'all',
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getVerifiedAgents',
    }),
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
    // Obter lista de assignees únicos dos contatos
    availableAssignees() {
      const assigneesMap = new Map();
      this.contacts.forEach(contact => {
        if (!contact.pipeline_positions) return;
        const position = contact.pipeline_positions.find(
          p => p.pipeline_id === this.pipelineId || p.pipeline_id === parseInt(this.pipelineId, 10)
        );
        if (position?.assignee) {
          if (!assigneesMap.has(position.assignee.id)) {
            assigneesMap.set(position.assignee.id, position.assignee);
          }
        }
      });
      return Array.from(assigneesMap.values());
    },
    // Contar filtros ativos
    activeFiltersCount() {
      let count = 0;
      if (this.selectedLabels.length > 0) count++;
      if (this.dealValueMin !== null && this.dealValueMin !== '') count++;
      if (this.dealValueMax !== null && this.dealValueMax !== '') count++;
      if (this.dateFrom) count++;
      if (this.dateTo) count++;
      if (this.selectedAssignees.length > 0) count++;
      if (this.winLostFilter !== 'all') count++;
      return count;
    },
    // Opções de assignee incluindo "Sem responsável"
    assigneeOptions() {
      const options = [...this.availableAssignees];
      // Adicionar opção "Sem responsável" se houver cards sem assignee
      const hasUnassigned = this.contacts.some(contact => {
        if (!contact.pipeline_positions) return false;
        const position = contact.pipeline_positions.find(
          p => p.pipeline_id === this.pipelineId || p.pipeline_id === parseInt(this.pipelineId, 10)
        );
        return position && !position.assignee;
      });
      if (hasUnassigned) {
        options.unshift({ id: null, name: this.$t('KANBAN.FILTERS.NO_ASSIGNEE') });
      }
      return options;
    },
    // Opções de status win/lost
    statusOptions() {
      return [
        { value: 'all', label: this.$t('KANBAN.FILTERS.ALL'), icon: 'list' },
        { value: 'open', label: this.$t('KANBAN.FILTERS.OPEN'), icon: 'clock' },
        { value: 'won', label: this.$t('KANBAN.FILTERS.WON'), icon: 'checkmark-circle' },
        { value: 'lost', label: this.$t('KANBAN.FILTERS.LOST'), icon: 'dismiss-circle' }
      ];
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
        this.selectedAssignees = newFilters.assignees || [];
        this.winLostFilter = newFilters.winLost || 'all';
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
      this.selectedAssignees = [];
      this.winLostFilter = 'all';
      this.emitFilters();
    },
    setWinLostFilter(value) {
      this.winLostFilter = value;
      this.emitFilters();
    },
    handleAssigneeChange() {
      this.emitFilters();
    },
    emitFilters() {
      this.$emit('filters-changed', {
        labels: this.selectedLabels,
        dealValueMin: this.dealValueMin,
        dealValueMax: this.dealValueMax,
        dateFrom: this.dateFrom,
        dateTo: this.dateTo,
        assignees: this.selectedAssignees,
        winLost: this.winLostFilter,
      });
      this.$emit('win-lost-filter', this.winLostFilter);
    },
  },
  mounted() {
    if (this.agents.length === 0) {
      this.$store.dispatch('agents/get');
    }
  },
};
</script>


