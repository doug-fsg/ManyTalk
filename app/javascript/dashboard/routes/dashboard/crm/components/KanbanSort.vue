<template>
  <div class="kanban-sort relative" v-on-clickaway="closeSort">
    <button
      type="button"
      @click.stop="toggleSort"
      :class="[
        'relative inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
        'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
        'hover:bg-slate-50 dark:hover:bg-slate-700',
        isNonDefaultSort ? 'bg-slate-50 dark:bg-slate-800/50 text-slate-700 dark:text-slate-200' : '',
        showSort ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100' : ''
      ]"
    >
      <fluent-icon icon="arrow-sort" size="14" />
      <span class="hidden lg:inline">{{ $t('KANBAN.SORT.TITLE') }}</span>
      <fluent-icon
        icon="chevron-down"
        size="10"
        :class="[
          'transition-transform duration-200',
          showSort ? 'rotate-180' : ''
        ]"
      />
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
        v-if="showSort"
        class="absolute left-0 mt-2 w-56 rounded-xl shadow-soft-xl bg-white dark:bg-slate-800 ring-1 ring-slate-200 dark:ring-slate-700 z-50 overflow-hidden animate-scale-in"
      >
        <div class="py-1">
          <button
            v-for="option in sortOptions"
            :key="option.value"
            type="button"
            class="w-full text-left px-3 py-2 text-sm flex items-center justify-between gap-2 transition-colors duration-150 ease-smooth focus:outline-none"
            :class="[
              sortBy === option.value
                ? 'bg-woot-50 text-woot-700 dark:bg-woot-900/20 dark:text-woot-300'
                : 'text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700/50'
            ]"
            @click="selectSort(option.value)"
          >
            <span>{{ option.label }}</span>
            <fluent-icon
              v-if="sortBy === option.value"
              icon="checkmark"
              size="12"
              class="text-woot-600 dark:text-woot-400 shrink-0"
            />
          </button>
        </div>
      </div>
    </transition>
  </div>
</template>

<script>
import { directive as onClickaway } from 'vue-clickaway';
import { DEFAULT_KANBAN_SORT } from '../utils/kanbanSortHelper';

export default {
  name: 'KanbanSort',
  directives: {
    onClickaway,
  },
  props: {
    sortBy: {
      type: String,
      default: DEFAULT_KANBAN_SORT,
    },
  },
  data() {
    return {
      showSort: false,
    };
  },
  computed: {
    isNonDefaultSort() {
      return this.sortBy !== DEFAULT_KANBAN_SORT;
    },
    sortOptions() {
      return [
        { value: 'name', label: this.$t('KANBAN.SORT.NAME_ASC') },
        { value: 'name_desc', label: this.$t('KANBAN.SORT.NAME_DESC') },
        { value: 'position', label: this.$t('KANBAN.SORT.POSITION') },
        { value: 'deal_value_desc', label: this.$t('KANBAN.SORT.DEAL_VALUE_DESC') },
        { value: 'deal_value_asc', label: this.$t('KANBAN.SORT.DEAL_VALUE_ASC') },
        { value: 'newest', label: this.$t('KANBAN.SORT.NEWEST') },
        { value: 'oldest', label: this.$t('KANBAN.SORT.OLDEST') },
        { value: 'time_in_stage', label: this.$t('KANBAN.SORT.TIME_IN_STAGE') },
      ];
    },
  },
  methods: {
    toggleSort() {
      this.showSort = !this.showSort;
    },
    closeSort() {
      this.showSort = false;
    },
    selectSort(value) {
      this.$emit('sort-changed', value);
      this.showSort = false;
    },
  },
};
</script>
