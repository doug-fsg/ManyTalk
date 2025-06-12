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
        <div class="hidden md:block relative">
          <button 
            data-dropdown="pipeline"
            class="flex items-center gap-2 px-3 py-1.5 rounded-lg shadow-sm ring-1 ring-black/5 border border-neutral-100 text-neutral-700 hover:bg-neutral-50 transition-colors dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700"
            @click="togglePipeline"
          >
            <fluent-icon icon="arrow-swap" size="16" class="text-neutral-500" />
            <span class="text-sm font-medium">{{ displayTitle }}</span>
            <fluent-icon icon="chevron-down" size="12" class="text-neutral-400" />
          </button>

          <!-- Pipeline Dropdown -->
          <div 
            v-if="showPipelineDropdown"
            data-dropdown="pipeline-content"
            class="absolute top-full left-0 mt-1 w-56 bg-white rounded-lg border border-neutral-50 py-1 z-50 dark:bg-slate-700 dark:border-slate-600"
          >
            <div v-if="pipelines && pipelines.length">
              <div 
                v-for="pipeline in pipelines"
                :key="pipeline.id"
                class="px-3 py-2 text-sm text-neutral-500 hover:bg-neutral-50 hover:text-neutral-700 cursor-pointer transition-colors dark:text-slate-300 dark:hover:bg-slate-600 dark:hover:text-slate-200"
                @click="selectPipeline(pipeline)"
              >
                {{ pipeline.attribute_display_name || pipeline.display_name || pipeline.name || 'Pipeline sem nome' }}
              </div>
            </div>
            <div v-else class="px-3 py-2 text-sm text-neutral-400 dark:text-slate-400">
              {{ $t('KANBAN.NO_PIPELINES') || 'Nenhum pipeline disponível' }}
            </div>
          </div>
        </div>

        <!-- Search -->
        <div class="hidden md:flex items-center">
          <button 
            @click="toggleSearch"
            class="p-1.5 rounded-lg text-neutral-600 hover:bg-neutral-100 transition-colors dark:text-slate-300 dark:hover:bg-slate-700"
          >
            <fluent-icon icon="search" size="16" />
          </button>
          <div v-show="showSearch" class="ml-2 animate-slide-in">
            <input 
              type="search" 
              v-model="searchQuery"
              :placeholder="$t('KANBAN.SEARCH_PLACEHOLDER') || 'Buscar contatos'"
              class="px-3 py-1.5 text-sm border border-neutral-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:placeholder-slate-400"
              @input="$emit('search', searchQuery)"
            />
          </div>
        </div>
      </div>

      <!-- Right Section -->
      <div class="flex items-center gap-2">
        <!-- Kanban Actions Dropdown -->
        <div v-if="isAdmin" class="relative">
          <button 
            data-dropdown="actions"
            @click="toggleKanbanActions"
            class="flex items-center gap-2 px-3 py-1.5 text-neutral-600 hover:text-neutral-800 transition-colors dark:text-slate-300 dark:hover:text-slate-200"
          >
            <fluent-icon icon="chevron-down" size="16" />
            <span class="hidden lg:inline text-sm">Ações</span>
            <fluent-icon icon="chevron-down" size="12" />
          </button>
          
          <!-- Actions Dropdown -->
          <div 
            v-if="showKanbanActions" 
            data-dropdown="actions-content"
            class="absolute right-0 mt-2 w-48 bg-white border border-neutral-50 rounded-lg py-1 z-50 dark:bg-slate-700 dark:border-slate-600"
          >
            <button 
              @click="createNewKanban"
              class="w-full flex items-center gap-2 px-3 py-2 text-left text-neutral-500 hover:bg-neutral-50 hover:text-neutral-700 first:rounded-t-lg text-sm transition-colors dark:text-slate-300 dark:hover:bg-slate-600 dark:hover:text-slate-200"
            >
              <fluent-icon icon="add" size="16" />
              Novo Kanban
            </button>
            <button 
              @click="editKanban"
              class="w-full flex items-center gap-2 px-3 py-2 text-left text-neutral-500 hover:bg-neutral-50 hover:text-neutral-700 text-sm transition-colors dark:text-slate-300 dark:hover:bg-slate-600 dark:hover:text-slate-200"
            >
              <fluent-icon icon="edit" size="16" />
              Editar Kanban
            </button>
            <button 
              @click="deleteKanban"
              class="w-full flex items-center gap-2 px-3 py-2 text-left text-red-400 hover:bg-red-50 hover:text-red-600 last:rounded-b-lg text-sm transition-colors dark:text-red-400 dark:hover:bg-red-900/20 dark:hover:text-red-300"
            >
              <fluent-icon icon="delete" size="16" />
              Excluir Kanban
            </button>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>

<script>
export default {
  name: 'KanbanHeader',
  props: {
    pipelineName: {
      type: String,
      required: false,
      default: ''
    },
    isAdmin: {
      type: Boolean,
      default: false
    },
    currentView: {
      type: String,
      default: 'kanban'
    },
    pipelines: {
      type: Array,
      default: () => []
    }
  },
  data() {
    return {
      showSearch: false,
      searchQuery: '',
      showPipelineDropdown: false,
      showKanbanActions: false
    }
  },
  computed: {
    displayTitle() {
      console.log('[KanbanDebug] Pipeline atual:', this.pipelineName);
      return this.pipelineName || this.$t('KANBAN.TITLE') || 'Pipeline';
    }
  },
  watch: {
    pipelines: {
      immediate: true,
      handler(newVal) {
        console.log('[KanbanDebug] Pipelines disponíveis:', newVal);
      }
    }
  },
  mounted() {
    window.addEventListener('click', this.handleClickOutside);
  },
  beforeDestroy() {
    window.removeEventListener('click', this.handleClickOutside);
  },
  methods: {
    toggleSearch() {
      this.showSearch = !this.showSearch
      if (!this.showSearch) {
        this.searchQuery = ''
        this.$emit('search', '')
      }
    },
    togglePipeline() {
      console.log('[KanbanDebug] Toggle pipeline dropdown');
      this.showPipelineDropdown = !this.showPipelineDropdown
    },
    toggleKanbanActions() {
      this.showKanbanActions = !this.showKanbanActions
    },
    selectPipeline(pipeline) {
      console.log('[KanbanDebug] Selecionando pipeline:', pipeline);
      this.$emit('select-pipeline', pipeline)
      this.showPipelineDropdown = false
    },
    setView(view) {
      this.$emit('update:currentView', view)
    },
    createNewKanban() {
      this.showKanbanActions = false
      this.$emit('create-new')
    },
    editKanban() {
      this.showKanbanActions = false
      this.$emit('edit-kanban')
    },
    deleteKanban() {
      this.showKanbanActions = false
      this.$emit('delete-kanban')
    },
    handleClickOutside(event) {
      // Pipeline dropdown
      const pipelineButton = this.$el.querySelector('[data-dropdown="pipeline"]');
      const pipelineDropdown = this.$el.querySelector('[data-dropdown="pipeline-content"]');
      if (pipelineDropdown && !pipelineDropdown.contains(event.target) && !pipelineButton.contains(event.target)) {
          this.showPipelineDropdown = false;
      }
      
      // Actions dropdown
      const actionsButton = this.$el.querySelector('[data-dropdown="actions"]');
      const actionsDropdown = this.$el.querySelector('[data-dropdown="actions-content"]');
      if (actionsDropdown && !actionsDropdown.contains(event.target) && !actionsButton.contains(event.target)) {
          this.showKanbanActions = false;
      }
    }
  }
}
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