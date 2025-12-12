<template>
  <div class="funnel-agents-section">
    <!-- Header colapsável -->
    <div 
      class="section-header"
      @click="isExpanded = !isExpanded"
    >
      <div class="header-left">
        <fluent-icon 
          :icon="isExpanded ? 'chevron-down' : 'chevron-right'" 
          size="16" 
          class="chevron-icon"
        />
        <fluent-icon icon="people" size="16" class="people-icon" />
        <h3 class="section-title">{{ $t('KANBAN.PERMISSIONS.TITLE') }}</h3>
      </div>
      <fluent-icon 
        icon="chevron-down" 
        size="16" 
        class="expand-icon"
        :class="{ 'rotate-180': isExpanded }"
      />
    </div>

    <!-- Conteúdo expansível -->
    <div v-if="isExpanded" class="section-content">
      <!-- Campo Visualizador -->
      <div class="permission-field">
        <label class="permission-label flex items-center gap-1.5">
          <span>{{ $t('KANBAN.PERMISSIONS.VIEWER') }}</span>
          <fluent-icon
            v-tooltip.left="$t('KANBAN.PERMISSIONS.VIEWER_TOOLTIP')"
            icon="info"
            size="14"
            class="text-slate-500 dark:text-slate-400 cursor-help shrink-0"
          />
        </label>
        <multiselect
          v-model="viewerAgents"
          :options="viewerAvailableAgents"
          track-by="id"
          label="name"
          :multiple="true"
          :close-on-select="false"
          :clear-on-select="false"
          :hide-selected="true"
          :placeholder="$t('KANBAN.PERMISSIONS.SELECT_VIEWERS')"
          selected-label
          :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
          :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
        />
      </div>

      <!-- Campo Editor -->
      <div class="permission-field">
        <label class="permission-label flex items-center gap-1.5">
          <span>{{ $t('KANBAN.PERMISSIONS.EDITOR') }}</span>
          <fluent-icon
            v-tooltip.left="$t('KANBAN.PERMISSIONS.EDITOR_TOOLTIP')"
            icon="info"
            size="14"
            class="text-slate-500 dark:text-slate-400 cursor-help shrink-0"
          />
        </label>
        <multiselect
          v-model="editorAgents"
          :options="editorAvailableAgents"
          track-by="id"
          label="name"
          :multiple="true"
          :close-on-select="false"
          :clear-on-select="false"
          :hide-selected="true"
          :placeholder="$t('KANBAN.PERMISSIONS.SELECT_EDITORS')"
          selected-label
          :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
          :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
        />
      </div>

      <!-- Campo Supervisor -->
      <div class="permission-field">
        <label class="permission-label flex items-center gap-1.5">
          <span>{{ $t('KANBAN.PERMISSIONS.SUPERVISOR') }}</span>
          <fluent-icon
            v-tooltip.left="$t('KANBAN.PERMISSIONS.SUPERVISOR_TOOLTIP')"
            icon="info"
            size="14"
            class="text-slate-500 dark:text-slate-400 cursor-help shrink-0"
          />
        </label>
        <multiselect
          v-model="supervisorAgents"
          :options="supervisorAvailableAgents"
          track-by="id"
          label="name"
          :multiple="true"
          :close-on-select="false"
          :clear-on-select="false"
          :hide-selected="true"
          :placeholder="$t('KANBAN.PERMISSIONS.SELECT_SUPERVISORS')"
          selected-label
          :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
          :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
        />
        <p class="permission-help-text">
          {{ $t('KANBAN.PERMISSIONS.SUPERVISOR_DESCRIPTION') }}
        </p>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';

export default {
  name: 'FunnelAgentsPermissions',
  props: {
    pipelineId: {
      type: [Number, String],
      required: true,
    },
    permissions: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      isExpanded: true,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getVerifiedAgents',
    }),
    availableAgents() {
      // Todos os agentes exceto administradores
      return this.agents.filter(agent => agent.role !== 'administrator');
    },
    viewerAvailableAgents() {
      // Agentes disponíveis para visualizador (não estão em editor ou supervisor)
      return this.availableAgents.filter(agent => 
        this.permissions[agent.id] !== 'editor' && 
        this.permissions[agent.id] !== 'supervisor'
      );
    },
    editorAvailableAgents() {
      // Agentes disponíveis para editor (não estão em viewer ou supervisor)
      return this.availableAgents.filter(agent => 
        this.permissions[agent.id] !== 'viewer' && 
        this.permissions[agent.id] !== 'supervisor'
      );
    },
    supervisorAvailableAgents() {
      // Agentes disponíveis para supervisor (não estão em viewer ou editor)
      return this.availableAgents.filter(agent => 
        this.permissions[agent.id] !== 'viewer' && 
        this.permissions[agent.id] !== 'editor'
      );
    },
    viewerAgents: {
      get() {
        return this.availableAgents.filter(agent => 
          this.permissions[agent.id] === 'viewer'
        );
      },
      set(value) {
        this.updateAgentsPermission(value, 'viewer', ['editor', 'supervisor']);
      }
    },
    editorAgents: {
      get() {
        return this.availableAgents.filter(agent => 
          this.permissions[agent.id] === 'editor'
        );
      },
      set(value) {
        this.updateAgentsPermission(value, 'editor', ['viewer', 'supervisor']);
      }
    },
    supervisorAgents: {
      get() {
        return this.availableAgents.filter(agent => 
          this.permissions[agent.id] === 'supervisor'
        );
      },
      set(value) {
        this.updateAgentsPermission(value, 'supervisor', ['viewer', 'editor']);
      }
    },
  },
  watch: {
    permissions: {
      handler() {
        // Trigger reatividade quando permissions mudar externamente
        this.$forceUpdate();
      },
      deep: true,
    },
  },
  mounted() {
    // Carregar agentes se ainda não estiverem carregados
    if (this.agents.length === 0) {
      this.$store.dispatch('agents/get');
    }
  },
  methods: {
    updateAgentsPermission(selectedAgents, permission, otherPermissions) {
      const updated = { ...this.permissions };
      const selectedIds = new Set(selectedAgents.map(a => a.id));
      const otherPermsArray = Array.isArray(otherPermissions) ? otherPermissions : [otherPermissions];
      
      // Remover apenas agentes que estavam nesta permissão mas não estão mais selecionados
      // ou que estavam nas outras permissões mas agora estão sendo movidos para esta
      this.availableAgents.forEach(agent => {
        const currentPerm = updated[agent.id];
        const isBeingMoved = otherPermsArray.includes(currentPerm) && selectedIds.has(agent.id);
        const wasRemoved = currentPerm === permission && !selectedIds.has(agent.id);
        
        if (isBeingMoved || wasRemoved) {
          delete updated[agent.id];
        }
      });
      
      // Adicionar os agentes selecionados com a nova permissão
      selectedAgents.forEach(agent => {
        updated[agent.id] = permission;
      });
      
      this.$emit('update:permissions', updated);
    },
  },
};
</script>

<style scoped lang="scss">
.funnel-agents-section {
  @apply mt-6 border border-slate-200 dark:border-slate-600 rounded-lg;
  overflow: visible;
}

.section-header {
  @apply flex items-center justify-between px-4 py-3 cursor-pointer;
  @apply bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700;
  @apply transition-colors duration-200;

  .header-left {
    @apply flex items-center gap-2;
  }

  .chevron-icon,
  .people-icon {
    @apply text-slate-600 dark:text-slate-400;
  }

  .section-title {
    @apply text-sm font-medium text-slate-900 dark:text-white;
  }

  .expand-icon {
    @apply text-slate-400 dark:text-slate-500 transition-transform duration-200;
  }
}

.section-content {
  @apply p-4 space-y-4 bg-white dark:bg-slate-900;
  overflow: visible;
}

.permission-field {
  @apply space-y-2;
  position: relative;
}

.permission-label {
  @apply text-sm font-medium text-slate-700 dark:text-slate-300;
}

.permission-help-text {
  @apply text-xs text-slate-500 dark:text-slate-400 mt-1;
}

// Garantir que tooltips apareçam acima do modal
::v-deep .tooltip {
  z-index: 10001 !important;
}

::v-deep .v-tooltip-container {
  z-index: 10001 !important;
}
</style>
