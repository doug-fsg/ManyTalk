<template>
  <div class="kanban-filters relative" v-on-clickaway="handleClickaway">
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
        class="absolute left-0 mt-2 w-[36rem] max-w-[calc(100vw-2rem)] rounded-xl shadow-soft-xl bg-white dark:bg-slate-800 ring-1 ring-slate-200 dark:ring-slate-700 z-50 animate-scale-in flex flex-col overflow-visible"
      >
        <div class="overflow-visible p-4 space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <div class="flex items-center gap-1 mb-1">
                <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
                  {{ $t('KANBAN.FILTERS.STATUS') }}
                </span>
                <fluent-icon
                  v-tooltip.top="$t('KANBAN.FILTERS.HELP.STATUS')"
                  icon="info"
                  size="12"
                  class="text-slate-400 dark:text-slate-500 cursor-help shrink-0"
                />
              </div>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="option in statusOptions"
                  :key="option.value"
                  type="button"
                  :class="[chipClass(winLostFilter === option.value), 'inline-flex items-center gap-1']"
                  @click="setWinLostFilter(option.value)"
                >
                  <fluent-icon :icon="option.icon" size="12" />
                  {{ option.label }}
                </button>
              </div>
            </div>

            <div v-if="showAssigneeFilter">
              <span class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1">
                {{ $t('KANBAN.FILTERS.ASSIGNEE') }}
              </span>
              <div class="multiselect-wrap--small" @click.stop>
                <multiselect
                  v-model="selectedAssigneeObjects"
                  :options="assigneeMultiselectOptions"
                  track-by="_key"
                  label="name"
                  :multiple="true"
                  :close-on-select="false"
                  :show-labels="false"
                  :placeholder="$t('KANBAN.FILTERS.ASSIGNEE_PLACEHOLDER')"
                  :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
                  deselect-label=""
                  :max-height="160"
                  class="no-margin"
                />
              </div>
            </div>
          </div>

          <div
            v-if="pipelineStages.length || (accountLabels || []).length"
            class="space-y-1.5"
          >
            <div
              v-if="showLabelScopeToggle && (accountLabels || []).length"
              class="flex justify-end gap-1"
            >
              <button
                type="button"
                :class="chipClass(labelScope === 'pipeline')"
                @click="setLabelScope('pipeline')"
              >
                {{ $t('KANBAN.FILTERS.LABELS_SCOPE_PIPELINE') }}
              </button>
              <button
                type="button"
                :class="chipClass(labelScope === 'all')"
                @click="setLabelScope('all')"
              >
                {{ $t('KANBAN.FILTERS.LABELS_SCOPE_ALL') }}
              </button>
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 items-start">
            <div v-if="pipelineStages.length" class="min-w-0">
              <div class="flex items-center gap-1 mb-1 min-h-[1.125rem]">
                <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
                  {{ $t('KANBAN.FILTERS.STAGES') }}
                </span>
                <fluent-icon
                  v-tooltip.top="$t('KANBAN.FILTERS.HELP.STAGES')"
                  icon="info"
                  size="12"
                  class="text-slate-400 dark:text-slate-500 cursor-help shrink-0"
                />
              </div>
              <div class="multiselect-wrap--small" @click.stop>
                <multiselect
                  v-model="selectedStageObjects"
                  :options="stageMultiselectOptions"
                  track-by="id"
                  label="name"
                  :multiple="true"
                  :close-on-select="false"
                  :show-labels="false"
                  :placeholder="$t('KANBAN.FILTERS.STAGES_PLACEHOLDER')"
                  :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
                  deselect-label=""
                  :max-height="160"
                  class="no-margin"
                />
              </div>
            </div>

            <div v-if="(accountLabels || []).length" class="min-w-0">
              <div class="flex items-center gap-1 mb-1 min-h-[1.125rem]">
                <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
                  {{ $t('KANBAN.FILTERS.LABELS') }}
                </span>
                <fluent-icon
                  v-tooltip.top="$t('KANBAN.FILTERS.HELP.LABELS')"
                  icon="info"
                  size="12"
                  class="text-slate-400 dark:text-slate-500 cursor-help shrink-0"
                />
              </div>
              <div class="multiselect-wrap--small" @click.stop>
                <multiselect
                  v-model="selectedLabelObjects"
                  :options="labelMultiselectOptions"
                  track-by="id"
                  label="title"
                  :multiple="true"
                  :close-on-select="false"
                  :show-labels="false"
                  :placeholder="$t('KANBAN.FILTERS.LABELS_PLACEHOLDER')"
                  :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
                  deselect-label=""
                  :max-height="160"
                  class="no-margin"
                >
                  <template slot="option" slot-scope="props">
                    <div class="flex items-center gap-1.5 min-w-0">
                      <span
                        class="w-2 h-2 rounded-full shrink-0"
                        :style="{ backgroundColor: props.option.color || '#94a3b8' }"
                      />
                      <span class="truncate">{{ props.option.title }}</span>
                    </div>
                  </template>
                </multiselect>
              </div>
            </div>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <div class="flex items-center gap-1 mb-1">
                <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
                  {{ $t('KANBAN.FILTERS.DEAL_VALUE') }}
                </span>
                <fluent-icon
                  v-tooltip.top="$t('KANBAN.FILTERS.HELP.DEAL_VALUE')"
                  icon="info"
                  size="12"
                  class="text-slate-400 dark:text-slate-500 cursor-help shrink-0"
                />
              </div>
              <div class="flex flex-wrap gap-1.5 mb-1.5">
                <button
                  v-for="option in dealPresenceOptions"
                  :key="option.value"
                  type="button"
                  :class="chipClass(dealPresence === option.value)"
                  @click="setDealPresence(option.value)"
                >
                  {{ option.label }}
                </button>
              </div>
              <div v-if="dealPresence !== 'without'" class="flex items-center gap-1.5">
                <input
                  v-model.number="dealValueMin"
                  type="number"
                  :placeholder="$t('KANBAN.FILTERS.MIN_VALUE')"
                  :class="[fieldClass, 'kanban-filter-field']"
                  @input="handleDealValueChange"
                />
                <span class="text-slate-400 text-xs">-</span>
                <input
                  v-model.number="dealValueMax"
                  type="number"
                  :placeholder="$t('KANBAN.FILTERS.MAX_VALUE')"
                  :class="[fieldClass, 'kanban-filter-field']"
                  @input="handleDealValueChange"
                />
              </div>
            </div>

            <div>
              <div class="flex items-center gap-1 mb-1">
                <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
                  {{ $t('KANBAN.FILTERS.STALE') }}
                </span>
                <fluent-icon
                  v-tooltip.top="$t('KANBAN.FILTERS.HELP.STALE')"
                  icon="info"
                  size="12"
                  class="text-slate-400 dark:text-slate-500 cursor-help shrink-0"
                />
              </div>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="days in staleDayPresets"
                  :key="days"
                  type="button"
                  :class="chipClass(Number(staleDays) === days)"
                  @click="setStaleDays(days)"
                >
                  {{ $t('KANBAN.FILTERS.STALE_DAYS', { days }) }}
                </button>
              </div>
            </div>
          </div>

          <div>
            <div class="flex items-center gap-1 mb-1">
              <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
                {{ $t('KANBAN.FILTERS.DATE_RANGE') }}
              </span>
              <fluent-icon
                v-tooltip.top="$t('KANBAN.FILTERS.HELP.DATE_RANGE')"
                icon="info"
                size="12"
                class="text-slate-400 dark:text-slate-500 cursor-help shrink-0"
              />
            </div>
            <div class="flex flex-wrap gap-1.5 mb-1.5">
              <button
                v-for="option in dateFieldOptions"
                :key="option.value"
                type="button"
                :class="chipClass(dateField === option.value)"
                @click="setDateField(option.value)"
              >
                {{ option.label }}
              </button>
            </div>
            <div class="space-y-0.5">
              <div class="flex items-center gap-1.5">
                <input
                  v-model="dateFrom"
                  type="date"
                  :placeholder="$t('KANBAN.FILTERS.FROM_DATE')"
                  :class="[fieldClass, 'kanban-filter-field kanban-filter-date']"
                  @change="handleDateChange"
                />
                <span class="text-slate-400 text-xs">-</span>
                <input
                  v-model="dateTo"
                  type="date"
                  :placeholder="$t('KANBAN.FILTERS.TO_DATE')"
                  :class="[fieldClass, 'kanban-filter-field kanban-filter-date']"
                  @change="handleDateChange"
                />
              </div>
              <div class="flex flex-wrap items-center gap-x-2 gap-y-0 pl-0.5">
                <button
                  v-for="preset in dateRangePresets"
                  :key="preset.id"
                  type="button"
                  class="text-[11px] leading-tight text-slate-500 dark:text-slate-400 hover:text-woot-600 dark:hover:text-woot-400 transition-colors"
                  @click="applyDateRangePreset(preset.id)"
                >
                  {{ preset.label }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between px-4 py-2.5 border-t border-slate-200 dark:border-slate-700">
          <button
            type="button"
            class="text-xs text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200"
            @click="clearFilters"
          >
            {{ $t('KANBAN.FILTERS.CLEAR_ALL') }}
          </button>
          <woot-button size="tiny" variant="smooth" @click="applyFilters">
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
import { normalizeKanbanDateRange } from '../utils/kanbanDateFilterHelper';
import {
  DEFAULT_KANBAN_DATE_FIELD,
  pipelineStageNames,
} from '../utils/kanbanFilterQueryHelper';
import {
  DEFAULT_KANBAN_FILTERS,
  formatLocalDateInput,
  mergeKanbanFilters,
  startOfLocalWeek,
} from '../utils/kanbanFilterState';

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
      default: () => ({ ...DEFAULT_KANBAN_FILTERS }),
    },
    showAssigneeFilter: {
      type: Boolean,
      default: false,
    },
    attributeValues: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      showFilters: false,
      selectedLabels: [],
      selectedStages: [],
      dealValueMin: null,
      dealValueMax: null,
      dealPresence: 'all',
      dateFrom: null,
      dateTo: null,
      dateField: DEFAULT_KANBAN_DATE_FIELD,
      staleDays: null,
      selectedAssignees: [],
      winLostFilter: 'open',
      labelMatchMode: 'any',
      staleDayPresets: [3, 7, 14, 30],
      winLostTouchedByUser: false,
      labelScope: 'pipeline',
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getVerifiedAgents',
      accountLabels: 'labels/getLabels',
    }),
    fieldClass() {
      return [
        'min-w-0 flex-1 h-8 px-2.5 py-1 text-xs leading-5 rounded-md border-0',
        'bg-slate-100 text-slate-700 placeholder:text-slate-400',
        'dark:bg-slate-700 dark:text-slate-200',
        'focus:outline-none focus:ring-1 focus:ring-woot-500',
      ];
    },
    assigneeMultiselectOptions() {
      return this.assigneeOptions.map(assignee => ({
        ...assignee,
        _key: assignee.id == null ? '__none__' : assignee.id,
      }));
    },
    selectedAssigneeObjects: {
      get() {
        const selectedKeys = new Set(
          this.selectedAssignees.map(assignee =>
            assignee?.id == null ? '__none__' : assignee.id
          )
        );
        return this.assigneeMultiselectOptions.filter(option =>
          selectedKeys.has(option._key)
        );
      },
      set(assignees) {
        this.selectedAssignees = (assignees || []).map(({ id, name }) => ({
          id,
          name,
        }));
        this.emitFilters();
      },
    },
    dateRangePresets() {
      return [
        { id: 'today', label: this.$t('KANBAN.FILTERS.DATE_PRESET_TODAY') },
        { id: 'yesterday', label: this.$t('KANBAN.FILTERS.DATE_PRESET_YESTERDAY') },
        { id: 'this_week', label: this.$t('KANBAN.FILTERS.DATE_PRESET_THIS_WEEK') },
      ];
    },
    labelMultiselectOptions() {
      return [...this.scopedLabelOptions].sort((a, b) =>
        (a.title || '').localeCompare(b.title || '')
      );
    },
    selectedLabelObjects: {
      get() {
        const ids = new Set(this.selectedLabels.map(id => Number(id)));
        return (this.accountLabels || []).filter(label => ids.has(label.id));
      },
      set(labels) {
        this.selectedLabels = (labels || []).map(label => label.id);
        this.emitFilters();
      },
    },
    stageMultiselectOptions() {
      return this.pipelineStages.map(name => ({ id: name, name }));
    },
    selectedStageObjects: {
      get() {
        const selected = new Set(this.selectedStages);
        return this.stageMultiselectOptions.filter(stage => selected.has(stage.id));
      },
      set(stages) {
        this.selectedStages = (stages || []).map(stage => stage.id);
        this.emitFilters();
      },
    },
    pipelineLabelIds() {
      const ids = new Set();
      (this.contacts || []).forEach(contact => {
        (contact.labels || []).forEach(label => {
          if (label?.id != null) ids.add(label.id);
        });
      });
      return ids;
    },
    showLabelScopeToggle() {
      return (this.accountLabels || []).length > 12 && this.pipelineLabelIds.size > 0;
    },
    scopedLabelOptions() {
      const account = this.accountLabels || [];
      const pipelineIds = this.pipelineLabelIds;
      const selected = new Set(this.selectedLabels);

      if (this.labelScope === 'all' || pipelineIds.size === 0) {
        return account;
      }

      return account.filter(
        label => pipelineIds.has(label.id) || selected.has(label.id)
      );
    },
    pipelineStages() {
      return pipelineStageNames(this.attributeValues);
    },
    dealPresenceOptions() {
      return [
        { value: 'all', label: this.$t('KANBAN.FILTERS.DEAL_ALL') },
        { value: 'with', label: this.$t('KANBAN.FILTERS.DEAL_WITH_VALUE') },
        { value: 'without', label: this.$t('KANBAN.FILTERS.DEAL_WITHOUT_VALUE') },
      ];
    },
    dateFieldOptions() {
      return [
        { value: 'created_at', label: this.$t('KANBAN.FILTERS.DATE_FIELD_CREATED') },
        { value: 'entered_at', label: this.$t('KANBAN.FILTERS.DATE_FIELD_STAGE') },
        { value: 'win_lost', label: this.$t('KANBAN.FILTERS.DATE_FIELD_WIN_LOST') },
      ];
    },
    availableAssignees() {
      const assigneesMap = new Map();
      const agentList = this.agents || [];
      if (agentList.length) {
        agentList.forEach(agent => {
          assigneesMap.set(agent.id, {
            id: agent.id,
            name: agent.available_name || agent.name,
          });
        });
      } else {
        this.contacts.forEach(contact => {
          const position = contact.pipeline_positions?.find(
            p => p.pipeline_id === this.pipelineId || p.pipeline_id === parseInt(this.pipelineId, 10)
          );
          if (position?.assignee && !assigneesMap.has(position.assignee.id)) {
            assigneesMap.set(position.assignee.id, position.assignee);
          }
        });
      }
      return Array.from(assigneesMap.values());
    },
    activeFiltersCount() {
      let count = 0;
      if (this.selectedLabels.length > 0) count++;
      if (this.selectedStages.length > 0) count++;
      if (this.dealPresence && this.dealPresence !== 'all') count++;
      if (this.dealPresence !== 'without') {
        if (this.dealValueMin !== null && this.dealValueMin !== '') count++;
        if (this.dealValueMax !== null && this.dealValueMax !== '') count++;
      }
      if (this.dateFrom) count++;
      if (this.dateTo) count++;
      if (this.staleDays) count++;
      if (this.selectedAssignees.length > 0) count++;
      if (this.winLostFilter !== 'open') count++;
      return count;
    },
    assigneeOptions() {
      const options = [...this.availableAssignees];
      options.unshift({ id: null, name: this.$t('KANBAN.FILTERS.NO_ASSIGNEE') });
      return options;
    },
    statusOptions() {
      return [
        { value: 'open', label: this.$t('KANBAN.FILTERS.OPEN'), icon: 'clock' },
        { value: 'won', label: this.$t('KANBAN.FILTERS.WON'), icon: 'checkmark-circle' },
        { value: 'lost', label: this.$t('KANBAN.FILTERS.LOST'), icon: 'dismiss-circle' },
        { value: 'all', label: this.$t('KANBAN.FILTERS.ALL'), icon: 'list' },
      ];
    },
  },
  watch: {
    filters: {
      handler(newFilters) {
        const next = mergeKanbanFilters(newFilters);
        this.selectedLabels = next.labels;
        this.selectedStages = next.stages;
        this.dealValueMin = next.dealValueMin;
        this.dealValueMax = next.dealValueMax;
        this.dealPresence = next.dealPresence;
        this.dateFrom = next.dateFrom;
        this.dateTo = next.dateTo;
        this.dateField = next.dateField;
        this.staleDays = next.staleDays;
        this.selectedAssignees = next.assignees;
        this.winLostFilter = next.winLost;
        this.labelMatchMode = next.labelMatchMode;
      },
      immediate: true,
      deep: true,
    },
    accountLabels(newLabels) {
      if (!newLabels?.length || !this.selectedLabels.length) return;
      const availableIds = new Set(newLabels.map(l => l.id));
      const pruned = this.selectedLabels.filter(id => availableIds.has(id));
      if (pruned.length !== this.selectedLabels.length) {
        this.selectedLabels = pruned;
        this.emitFilters();
      }
    },
    pipelineStages(newStages) {
      if (!this.selectedStages.length) return;
      const available = new Set(newStages);
      const pruned = this.selectedStages.filter(stage => available.has(stage));
      if (pruned.length !== this.selectedStages.length) {
        this.selectedStages = pruned;
        this.emitFilters();
      }
    },
  },
  methods: {
    chipClass(active) {
      return [
        'px-2 py-1 rounded-lg text-xs transition-colors duration-150 ease-smooth',
        active
          ? 'bg-woot-500 text-white'
          : 'bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600',
      ];
    },
    toggleFilters() {
      this.showFilters = !this.showFilters;
    },
    closeFilters() {
      this.showFilters = false;
    },
    handleClickaway(event) {
      const target = event?.target;
      if (target?.closest?.('.multiselect')) return;
      this.closeFilters();
    },
    setLabelScope(scope) {
      this.labelScope = scope;
    },
    applyDateRangePreset(presetId) {
      const today = new Date();
      if (presetId === 'today') {
        const day = formatLocalDateInput(today);
        this.dateFrom = day;
        this.dateTo = day;
      } else if (presetId === 'yesterday') {
        const yesterday = new Date(
          today.getFullYear(),
          today.getMonth(),
          today.getDate() - 1
        );
        const day = formatLocalDateInput(yesterday);
        this.dateFrom = day;
        this.dateTo = day;
      } else if (presetId === 'this_week') {
        this.dateFrom = formatLocalDateInput(startOfLocalWeek(today));
        this.dateTo = formatLocalDateInput(today);
      }
      this.normalizeDatesAndMaybePromoteWinLost();
      this.emitFilters();
    },
    applyFilterState(next) {
      const merged = mergeKanbanFilters(next);
      this.selectedLabels = merged.labels;
      this.selectedStages = merged.stages;
      this.dealValueMin = merged.dealValueMin;
      this.dealValueMax = merged.dealValueMax;
      this.dealPresence = merged.dealPresence;
      this.dateFrom = merged.dateFrom;
      this.dateTo = merged.dateTo;
      this.dateField = merged.dateField;
      this.staleDays = merged.staleDays;
      this.selectedAssignees = merged.assignees;
      this.winLostFilter = merged.winLost;
      this.labelMatchMode = merged.labelMatchMode;
      this.winLostTouchedByUser = merged.winLost && merged.winLost !== 'open';
      this.emitFilters();
    },
    setDealPresence(value) {
      this.dealPresence = value;
      if (value === 'without') {
        this.dealValueMin = null;
        this.dealValueMax = null;
      }
      this.emitFilters();
    },
    setDateField(value) {
      this.dateField = value;
      this.emitFilters();
    },
    setStaleDays(days) {
      this.staleDays = Number(this.staleDays) === days ? null : days;
      this.emitFilters();
    },
    handleDealValueChange() {
      this.emitFilters();
    },
    handleDateChange() {
      this.normalizeDatesAndMaybePromoteWinLost();
      this.emitFilters();
    },
    applyFilters() {
      this.normalizeDatesAndMaybePromoteWinLost();
      this.emitFilters();
      this.closeFilters();
    },
    clearFilters() {
      this.applyFilterState(DEFAULT_KANBAN_FILTERS);
      this.winLostTouchedByUser = false;
      this.labelScope = this.pipelineLabelIds.size > 0 ? 'pipeline' : 'all';
    },
    setWinLostFilter(value) {
      this.winLostTouchedByUser = true;
      this.winLostFilter = value;
      this.emitFilters();
    },
    normalizeDatesAndMaybePromoteWinLost() {
      const normalized = normalizeKanbanDateRange(this.dateFrom, this.dateTo);
      this.dateFrom = normalized.dateFrom;
      this.dateTo = normalized.dateTo;
      if (
        (this.dateFrom || this.dateTo) &&
        this.winLostFilter === 'open' &&
        !this.winLostTouchedByUser
      ) {
        this.winLostFilter = 'all';
      }
    },
    emitFilters() {
      this.$emit('filters-changed', {
        labels: this.selectedLabels,
        stages: this.selectedStages,
        dealValueMin: this.dealValueMin ?? null,
        dealValueMax: this.dealValueMax ?? null,
        dealPresence: this.dealPresence,
        dateFrom: this.dateFrom,
        dateTo: this.dateTo,
        dateField: this.dateField,
        staleDays: this.staleDays,
        assignees: this.selectedAssignees,
        winLost: this.winLostFilter,
        labelMatchMode: 'any',
      });
      this.$emit('win-lost-filter', this.winLostFilter);
    },
  },
  mounted() {
    if (this.agents.length === 0) {
      this.$store.dispatch('agents/get');
    }
    if (!this.accountLabels?.length) {
      this.$store.dispatch('labels/get');
    }
  },
};
</script>

<style scoped lang="scss">
.kanban-filter-field {
  min-height: 2rem;
  max-height: 2rem;
}

.kanban-filter-date {
  color-scheme: light;
}

.dark .kanban-filter-date {
  color-scheme: dark;
}

.kanban-filter-date::-webkit-datetime-edit,
.kanban-filter-date::-webkit-datetime-edit-fields-wrapper {
  padding: 0;
  font-size: 12px;
  line-height: 1.25rem;
}

.kanban-filter-date::-webkit-calendar-picker-indicator {
  margin: 0;
  padding: 0;
  transform: scale(0.75);
  transform-origin: center;
}
</style>
