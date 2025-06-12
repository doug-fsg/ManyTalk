<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <header class="bg-white shadow-sm px-4 py-3 dark:bg-slate-800">
    <div class="flex items-center justify-between">
      <!-- Left Section -->
      <div class="flex items-center gap-4">
        <!-- View Toggle Buttons -->
        <div class="hidden md:flex items-center gap-1 bg-neutral-100 rounded-lg p-1 dark:bg-slate-700">
          <button 
            :class="[
              'p-1.5 rounded-md transition-colors flex items-center gap-1',
              currentView === 'kanban' ? 'bg-white shadow-sm text-neutral-700' : 'text-neutral-600 hover:text-neutral-800'
            ]"
            @click="setView('kanban')"
          >
            <fluent-icon icon="kanban" size="16" />
          </button>
          <button 
            :class="[
              'p-1.5 rounded-md transition-colors flex items-center gap-1',
              currentView === 'list' ? 'bg-white shadow-sm text-neutral-700' : 'text-neutral-600 hover:text-neutral-800'
            ]"
            @click="setView('list')"
          >
            <fluent-icon icon="list" size="16" />
          </button>
        </div>

        <!-- Pipeline Selector -->
        <div class="hidden md:block relative" v-on-clickaway="closePipelineDropdown">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            class="flex items-center gap-2 text-slate-700 dark:text-slate-200"
            @click.stop="togglePipeline"
          >
            <fluent-icon icon="arrow-swap" size="16" class="text-slate-600 dark:text-slate-300" />
            <span class="text-sm font-medium">{{ displayTitle }}</span>
            <fluent-icon icon="chevron-down" size="12" class="text-slate-500 dark:text-slate-400" />
          </woot-button>

          <transition
            enter-active-class="transition ease-out duration-100"
            enter-from-class="transform opacity-0 scale-95"
            enter-to-class="transform opacity-100 scale-100"
            leave-active-class="transition ease-in duration-75"
            leave-from-class="transform opacity-100 scale-100"
            leave-to-class="transform opacity-0 scale-95"
          >
            <div v-if="showPipelineDropdown" class="absolute left-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-slate-800 ring-1 ring-black ring-opacity-5 z-50">
              <div v-if="pipelines && pipelines.length" class="py-1">
                <button
                  v-for="pipeline in pipelines"
                  :key="pipeline.id"
                  class="w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 focus:outline-none focus:bg-slate-100 dark:focus:bg-slate-700"
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

        <!-- Search -->
        <div class="hidden md:flex items-center">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            class="text-slate-700 dark:text-slate-200"
            @click="toggleSearch"
          >
            <fluent-icon icon="search" size="16" />
          </woot-button>
          <div v-show="showSearch" class="ml-2 animate-slide-in">
            <input 
              type="search" 
              v-model="searchQuery"
              :placeholder="$t('KANBAN.SEARCH_PLACEHOLDER')"
              class="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:placeholder-slate-400"
              @input="$emit('search', searchQuery)"
            />
          </div>
        </div>
      </div>

      <!-- Right Section -->
      <div class="flex items-center gap-2">
        <!-- Kanban Actions Dropdown -->
        <div class="relative" v-on-clickaway="closeKanbanActions">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            class="flex items-center gap-2 text-slate-700 dark:text-slate-200"
            @click.stop="toggleKanbanActions"
          >
            <fluent-icon icon="more-horizontal" size="16" class="text-slate-600 dark:text-slate-300" />
            <span class="hidden lg:inline text-sm">{{ $t('KANBAN.ACTIONS.TITLE') }}</span>
            <fluent-icon icon="chevron-down" size="12" class="text-slate-500 dark:text-slate-400" />
          </woot-button>
          
          <transition
            enter-active-class="transition ease-out duration-100"
            enter-from-class="transform opacity-0 scale-95"
            enter-to-class="transform opacity-100 scale-100"
            leave-active-class="transition ease-in duration-75"
            leave-from-class="transform opacity-100 scale-100"
            leave-to-class="transform opacity-0 scale-95"
          >
            <div v-if="showKanbanActions" class="absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white dark:bg-slate-800 ring-1 ring-black ring-opacity-5 z-50">
              <div class="py-1">
                <button
                  class="w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 focus:outline-none focus:bg-slate-100 dark:focus:bg-slate-700 flex items-center"
                  @click="createNewKanban"
                >
                  <fluent-icon icon="add" size="16" class="mr-2 text-slate-700 dark:text-slate-300" />
                  <span>{{ $t('KANBAN.ACTIONS.NEW') }}</span>
                </button>
                <button
                  class="w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 focus:outline-none focus:bg-slate-100 dark:focus:bg-slate-700 flex items-center"
                  @click="editKanban"
                >
                  <fluent-icon icon="edit" size="16" class="mr-2 text-slate-700 dark:text-slate-300" />
                  <span>{{ $t('KANBAN.ACTIONS.EDIT') }}</span>
                </button>
                <button
                  class="w-full text-left px-4 py-2 text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 focus:outline-none focus:bg-red-50 dark:focus:bg-red-900/20 flex items-center"
                  @click="deleteKanban"
                >
                  <fluent-icon icon="delete" size="16" class="mr-2" />
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

export default {
  name: 'KanbanHeader',
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
  },
  data() {
    return {
      showSearch: false,
      searchQuery: '',
      showPipelineDropdown: false,
      showKanbanActions: false,
    };
  },
  computed: {
    displayTitle() {
      return this.pipelineName || this.$t('KANBAN.TITLE');
    },
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
      this.$emit('update:currentView', view);
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
  },
};
</script>

<style scoped>
.animate-slide-in {
  animation: slideIn 0.2s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(-10px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}
</style>