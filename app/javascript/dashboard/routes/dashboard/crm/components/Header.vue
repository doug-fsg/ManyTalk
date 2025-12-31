<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <header class="bg-white border-b border-slate-200 dark:border-slate-700 px-4 py-3 dark:bg-slate-800">
    <div class="flex items-center justify-between">
      <!-- Left Section -->
      <div class="flex items-center gap-4">
        <!-- View Toggle Buttons -->
        <div ref="viewToggleContainer" class="hidden md:flex items-center gap-0.5 bg-slate-100/60 rounded-lg p-0.5 dark:bg-slate-700/50 relative">
          <!-- Animated Badge Background -->
          <div
            :style="badgeStyle"
            class="absolute h-[calc(100%-4px)] rounded-md bg-woot-500 dark:bg-woot-800 transition-all duration-300 ease-out top-[2px] z-0"
            style="pointer-events: none;"
          />
          
          <button 
            ref="kanbanButton"
            :class="[
              'px-2.5 py-1.5 rounded-lg transition-colors duration-200 ease-smooth flex items-center gap-1.5 text-xs font-medium relative z-10',
              currentView === 'kanban' ? 'text-white' : 'text-slate-600 dark:text-slate-300'
            ]"
            @click="setView('kanban')"
            v-tooltip.top="'Kanban'"
          >
            <fluent-icon icon="kanban" size="14" />
            <span class="hidden lg:inline">Kanban</span>
          </button>
          <button 
            ref="dashboardButton"
            :class="[
              'px-2.5 py-1.5 rounded-lg transition-colors duration-200 ease-smooth flex items-center gap-1.5 text-xs font-medium relative z-10',
              currentView === 'dashboard' ? 'text-white' : 'text-slate-600 dark:text-slate-300'
            ]"
            @click="setView('dashboard')"
            v-tooltip.top="'Dashboard'"
          >
            <fluent-icon icon="chart" size="14" />
            <span class="hidden lg:inline">Dashboard</span>
          </button>
          <button 
            ref="listButton"
            :class="[
              'px-2.5 py-1.5 rounded-lg transition-colors duration-200 ease-smooth flex items-center gap-1.5 text-xs font-medium relative z-10',
              currentView === 'list' ? 'text-white' : 'text-slate-600 dark:text-slate-300'
            ]"
            @click="setView('list')"
            v-tooltip.top="'Lista'"
          >
            <fluent-icon icon="list" size="14" />
            <span class="hidden lg:inline">Lista</span>
          </button>
        </div>

        <!-- Pipeline Selector -->
        <div class="hidden md:block relative" v-on-clickaway="closePipelineDropdown">
          <button
            @click.stop="togglePipeline"
            :class="[
              'relative inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
              'text-slate-700 dark:text-slate-200 hover:text-slate-900 dark:hover:text-slate-100',
              'hover:bg-slate-50 dark:hover:bg-slate-700',
              showPipelineDropdown ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100' : ''
            ]"
          >
            <fluent-icon icon="arrow-swap" size="14" class="text-slate-600 dark:text-slate-300" />
            <span class="font-medium">{{ displayTitle }}</span>
            <fluent-icon 
              icon="chevron-down" 
              size="10" 
              :class="[
                'transition-transform duration-200',
                showPipelineDropdown ? 'rotate-180' : ''
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
            <div v-if="showPipelineDropdown" class="absolute left-0 mt-2 w-56 rounded-xl shadow-soft-xl bg-white dark:bg-slate-800 ring-1 ring-slate-200 dark:ring-slate-700 z-50 overflow-hidden animate-scale-in">
              <div v-if="pipelines && pipelines.length" class="py-1">
                <button
                  v-for="pipeline in pipelines"
                  :key="pipeline.id"
                  class="w-full text-left px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700/50 focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-700/50 transition-colors duration-150 ease-smooth"
                  @click="selectPipeline(pipeline)"
                >
                  {{ pipeline.attribute_display_name || pipeline.display_name || pipeline.name || $t('KANBAN.NO_VALUE') }}
                </button>
              </div>
              <div v-else class="py-2 px-3 text-sm text-slate-500 dark:text-slate-400">
                {{ $t('KANBAN.NO_PIPELINES') }}
              </div>
            </div>
          </transition>
        </div>

        <!-- Filters -->
        <kanban-filters
          :contacts="contacts"
          :pipeline-id="pipelineId"
          :filters="filters"
          :show-assignee-filter="showAssigneeFilter"
          @filters-changed="handleFiltersChanged"
          @win-lost-filter="handleWinLostFilter"
        />

        <!-- Search -->
        <div class="hidden md:flex items-center gap-2">
          <button
            @click="toggleSearch"
            :class="[
              'relative inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
              'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
              'hover:bg-slate-50 dark:hover:bg-slate-700',
              showSearch ? 'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-400' : ''
            ]"
            v-tooltip.top="showSearch ? '' : $t('KANBAN.SEARCH_PLACEHOLDER')"
          >
            <fluent-icon icon="search" size="14" />
          </button>
          <transition
            enter-active-class="transition ease-out duration-200"
            enter-from-class="opacity-0 transform -translate-x-2"
            enter-to-class="opacity-100 transform translate-x-0"
            leave-active-class="transition ease-in duration-150"
            leave-from-class="opacity-100 transform translate-x-0"
            leave-to-class="opacity-0 transform -translate-x-2"
          >
            <input 
              v-show="showSearch"
              type="search" 
              v-model="searchQuery"
              :placeholder="$t('KANBAN.SEARCH_PLACEHOLDER')"
              class="px-3 py-1.5 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:placeholder-slate-400 w-48 transition-colors duration-150 ease-smooth"
              @input="$emit('search', searchQuery)"
            />
          </transition>
        </div>
      </div>

      <!-- Right Section -->
      <div class="flex items-center gap-2">
        <!-- Kanban Actions Dropdown -->
        <div class="relative" v-on-clickaway="closeKanbanActions">
          <button
            @click.stop="toggleKanbanActions"
            :class="[
              'relative inline-flex items-center gap-2 px-2.5 py-1.5 rounded-md text-xs font-medium transition-all duration-200',
              'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
              'hover:bg-slate-100 dark:hover:bg-slate-700',
              showKanbanActions ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100' : ''
            ]"
          >
            <fluent-icon icon="more-horizontal" size="14" />
            <span class="hidden lg:inline">{{ $t('KANBAN.ACTIONS.TITLE') }}</span>
            <fluent-icon 
              icon="chevron-down" 
              size="10" 
              :class="[
                'transition-transform duration-200',
                showKanbanActions ? 'rotate-180' : ''
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
            <div v-if="showKanbanActions" class="absolute right-0 mt-2 w-48 rounded-xl shadow-soft-xl bg-white dark:bg-slate-800 ring-1 ring-slate-200 dark:ring-slate-700 z-50 overflow-hidden animate-scale-in">
              <div class="py-1">
                <button
                  class="w-full text-left px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-woot-50 dark:hover:bg-woot-900/20 focus:outline-none focus:bg-woot-50 dark:focus:bg-woot-900/20 flex items-center gap-2 transition-colors duration-150"
                  @click="createNewKanban"
                >
                  <fluent-icon icon="add" size="14" class="text-woot-600 dark:text-woot-400" />
                  <span>{{ $t('KANBAN.ACTIONS.NEW') }}</span>
                </button>
                <button
                  class="w-full text-left px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700/50 focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-700/50 flex items-center gap-2 transition-colors duration-150"
                  @click="editKanban"
                >
                  <fluent-icon icon="edit" size="14" class="text-slate-600 dark:text-slate-400" />
                  <span>{{ $t('KANBAN.ACTIONS.EDIT') }}</span>
                </button>
                <div class="border-t border-slate-200 dark:border-slate-700 my-1"></div>
                <button
                  class="w-full text-left px-3 py-2 text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 focus:outline-none focus:bg-red-50 dark:focus:bg-red-900/20 flex items-center gap-2 transition-colors duration-150"
                  @click="deleteKanban"
                >
                  <fluent-icon icon="delete" size="14" />
                  <span>{{ $t('KANBAN.ACTIONS.DELETE') }}</span>
                </button>
              </div>
            </div>
          </transition>
        </div>
      </div>
    </div>
  </header>
</template>

<script>
import { directive as onClickaway } from 'vue-clickaway';
import KanbanFilters from './KanbanFilters.vue';

export default {
  name: 'KanbanHeader',
  components: {
    KanbanFilters,
  },
  directives: {
    onClickaway,
  },
  props: {
    pipelineName: {
      type: String,
      required: false,
      default: '',
    },
    currentView: {
      type: String,
      default: 'kanban',
    },
    pipelines: {
      type: Array,
      default: () => [],
    },
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
      showSearch: false,
      searchQuery: '',
      showPipelineDropdown: false,
      showKanbanActions: false,
      badgeStyle: {
        left: '2px',
        width: '0px',
      },
    };
  },
  computed: {
    displayTitle() {
      return this.pipelineName || this.$t('KANBAN.TITLE');
    },
  },
  watch: {
    currentView() {
      this.$nextTick(() => {
        this.updateBadgePosition();
      });
    },
  },
  mounted() {
    this.$nextTick(() => {
      setTimeout(() => {
        this.updateBadgePosition();
      }, 150);
    });
    if (typeof window !== 'undefined') {
      window.addEventListener('resize', this.updateBadgePosition);
    }
  },
  beforeDestroy() {
    if (typeof window !== 'undefined') {
      window.removeEventListener('resize', this.updateBadgePosition);
    }
  },
  methods: {
    toggleSearch() {
      this.showSearch = !this.showSearch;
      if (!this.showSearch) {
        this.searchQuery = '';
        this.$emit('search', '');
      }
    },
    togglePipeline() {
      this.showPipelineDropdown = !this.showPipelineDropdown;
      if (this.showPipelineDropdown) {
        this.showKanbanActions = false;
      }
    },
    toggleKanbanActions() {
      this.showKanbanActions = !this.showKanbanActions;
      if (this.showKanbanActions) {
        this.showPipelineDropdown = false;
      }
    },
    closePipelineDropdown() {
      this.showPipelineDropdown = false;
    },
    closeKanbanActions() {
      this.showKanbanActions = false;
    },
    selectPipeline(pipeline) {
      this.$emit('select-pipeline', pipeline);
      this.showPipelineDropdown = false;
    },
    setView(view) {
      this.$emit('update:current-view', view);
    },
    createNewKanban() {
      this.showKanbanActions = false;
      this.$emit('create-new');
    },
    editKanban() {
      this.showKanbanActions = false;
      this.$emit('edit-kanban');
    },
    deleteKanban() {
      this.showKanbanActions = false;
      this.$emit('delete-kanban');
    },
    handleWinLostFilter(filter) {
      this.$emit('win-lost-filter', filter);
    },
    handleFiltersChanged(filters) {
      this.$emit('filters-changed', filters);
    },
    updateBadgePosition() {
      this.$nextTick(() => {
        if (!this.$refs.viewToggleContainer) {
          setTimeout(() => this.updateBadgePosition(), 50);
          return;
        }

        let activeButton = null;
        if (this.currentView === 'kanban' && this.$refs.kanbanButton) {
          activeButton = this.$refs.kanbanButton;
        } else if (this.currentView === 'dashboard' && this.$refs.dashboardButton) {
          activeButton = this.$refs.dashboardButton;
        } else if (this.currentView === 'list' && this.$refs.listButton) {
          activeButton = this.$refs.listButton;
        }

        if (!activeButton) {
          setTimeout(() => this.updateBadgePosition(), 50);
          return;
        }

        const containerRect = this.$refs.viewToggleContainer.getBoundingClientRect();
        const buttonRect = activeButton.getBoundingClientRect();
        
        this.badgeStyle = {
          left: `${buttonRect.left - containerRect.left}px`,
          width: `${buttonRect.width}px`,
        };
      });
    },
  },
};
</script>
