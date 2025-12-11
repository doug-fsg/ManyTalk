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
        <h3 class="section-title">Permissões</h3>
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
        <label class="permission-label">
          Visualizador
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
          placeholder="Selecione agentes visualizadores"
          selected-label
          :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
          :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
        />
      </div>

      <!-- Campo Editor -->
      <div class="permission-field">
        <label class="permission-label">
          Editor
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
          placeholder="Selecione agentes editores"
          selected-label
          :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
          :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
        />
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
      // Agentes disponíveis para visualizador (não estão em editor)
      return this.availableAgents.filter(agent => 
        this.permissions[agent.id] !== 'editor'
      );
    },
    editorAvailableAgents() {
      // Agentes disponíveis para editor (não estão em viewer)
      return this.availableAgents.filter(agent => 
        this.permissions[agent.id] !== 'viewer'
      );
    },
    viewerAgents: {
      get() {
        return this.availableAgents.filter(agent => 
          this.permissions[agent.id] === 'viewer'
        );
      },
      set(value) {
        this.updateAgentsPermission(value, 'viewer', 'editor');
      }
    },
    editorAgents: {
      get() {
        return this.availableAgents.filter(agent => 
          this.permissions[agent.id] === 'editor'
        );
      },
      set(value) {
        this.updateAgentsPermission(value, 'editor', 'viewer');
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
    updateAgentsPermission(selectedAgents, permission, otherPermission) {
      const updated = { ...this.permissions };
      
      // Remover todos os agentes desta permissão e da outra permissão
      this.availableAgents.forEach(agent => {
        if (updated[agent.id] === permission || updated[agent.id] === otherPermission) {
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
}

.permission-label {
  @apply block text-sm font-medium text-slate-700 dark:text-slate-300;
}
</style>
