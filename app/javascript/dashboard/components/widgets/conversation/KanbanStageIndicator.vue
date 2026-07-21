<template>
  <div
    v-if="hasKanbanStages"
    ref="stageContainer"
    v-resize="computeVisibleStagePosition"
  >
    <div
      class="flex items-end flex-shrink min-w-0 gap-1"
      :class="{ 'h-auto overflow-visible flex-row flex-wrap': showAllStages }"
      >
      <!-- Pílulas dos pipelines -->
      <router-link
        v-for="(stage, index) in kanbanStages"
        :key="`pipeline-${stage.id}-${stage.stageName}`"
        :to="kanbanLinkForStage(stage)"
        class="relative inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-full tooltip-container cursor-pointer hover:opacity-90 focus:outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
        :class="[
          { hidden: !showAllStages && index > stagePosition },
          stage.statusType === 'won' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300' :
          stage.statusType === 'lost' ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300' :
          'bg-violet-100 text-violet-700 dark:bg-violet-900/30 dark:text-violet-300'
        ]"
        :title="$t('ACTIVITIES.DETAIL.OPEN_IN_PIPELINE')"
        @click.native.stop
      >
        <span class="truncate max-w-16">{{ stage.displayText }}</span>
        <fluent-icon
          icon="info"
          size="12"
          class="cursor-help"
        />
          
        <!-- Tooltip customizado -->
        <div class="tooltip-content">
          <div class="mb-1">
            <span class="font-semibold">Pipeline:</span> {{ stage.pipelineName }}
          </div>
          
          <!-- Status e data para ganho/perdido -->
          <div v-if="stage.statusType === 'won'" class="mb-1">
            <span class="font-semibold">Status:</span> 
            <span class="text-green-400">Ganho</span>
            <span v-if="stage.statusDate" class="ml-2 text-gray-300">
              em {{ formatDate(stage.statusDate) }}
            </span>
          </div>
          
          <div v-if="stage.statusType === 'lost'" class="mb-1">
            <span class="font-semibold">Status:</span> 
            <span class="text-red-400">Perdido</span>
            <span v-if="stage.statusDate" class="ml-2 text-gray-300">
              em {{ formatDate(stage.statusDate) }}
            </span>
          </div>
          
          <!-- Etapa ativa -->
          <div v-if="stage.statusType === 'active'" class="mb-1">
            <span class="font-semibold">Etapa:</span> {{ stage.stageName }}
          </div>
          
          <div v-if="stage.timeInStage" class="mb-1">
            <span class="font-semibold">Tempo na etapa:</span> {{ stage.timeInStage }}
          </div>
          
          <div v-if="stage.dealValue">
            <span class="font-semibold">Valor do negócio:</span> {{ formatCurrency(stage.dealValue) }}
          </div>
          
          <!-- Seta do tooltip - agora apontando para cima -->
          <div class="tooltip-arrow"></div>
        </div>
      </router-link>

      <!-- Botão mostrar mais -->
      <woot-button
        v-if="showExpandButton"
        :title="
          showAllStages
            ? $t('CONVERSATION.CARD.HIDE_STAGES')
            : $t('CONVERSATION.CARD.SHOW_STAGES')
        "
        class="sticky right-0 flex-shrink-0 mr-6 show-more--button rtl:rotate-180"
        color-scheme="secondary"
        variant="hollow"
        :icon="showAllStages ? 'chevron-left' : 'chevron-right'"
        size="tiny"
        @click="onShowStages"
      />
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { buildKanbanDeepLink } from 'dashboard/routes/dashboard/crm/utils/crmNavigationHelper';

export default {
  name: 'KanbanStageIndicator',
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      showAllStages: false,
      showExpandButton: false,
      stagePosition: -1,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
    }),
    // Buscar todos os atributos kanban
    kanbanAttributes() {
      return this.$store.getters['attributes/getAttributes'].filter(
        record => record.attribute_model === 'contact_attribute' && record.is_kanban === true
      );
    },
    // Processar todos os pipelines e suas etapas usando pipeline_positions
    kanbanStages() {
      if (!this.contact.pipeline_positions || !Array.isArray(this.contact.pipeline_positions)) {
        return [];
      }

      return this.kanbanAttributes.map(attribute => {
        // Buscar posição do pipeline usando pipeline_positions
        const position = this.contact.pipeline_positions.find(
          p => p.pipeline_id === attribute.id
        );
        
        if (!position || !position.stage_id) return null;

        const stageValue = position.stage_id;

        // Encontrar o nome legível da etapa
        const stages = attribute.attribute_values || [];
        // Suporta formato novo {name, color} e formato legado {key, value}
        const stage = stages.find(s => {
          if (typeof s === 'object' && s !== null) {
            return (s.name || s.value || s.key) === stageValue;
          }
          return s === stageValue;
        });
        const stageName = stage 
          ? (typeof stage === 'object' && stage !== null 
              ? (stage.name || stage.value || stageValue)
              : stage)
          : stageValue;

        // Buscar dados do pipeline_positions
        const dealValue = position.deal_value || 0;
        const enteredAt = position.entered_at;
        const metadata = position.metadata || {};
        const winLostData = metadata.win_lost || {};
        
        const isWon = winLostData.status === 'won';
        const isLost = winLostData.status === 'lost';
        const wonDate = winLostData.date;
        const lostDate = winLostData.date;

        // Determinar o status e texto a mostrar
        let displayText, statusType, statusDate;
        if (isWon) {
          displayText = 'Ganho';
          statusType = 'won';
          statusDate = wonDate;
        } else if (isLost) {
          displayText = 'Perdido';
          statusType = 'lost';
          statusDate = lostDate;
        } else {
          displayText = stageName;
          statusType = 'active';
          statusDate = null;
        }

        // Calcular tempo na etapa (só para etapas ativas)
        let timeInStage = null;
        if (statusType === 'active' && enteredAt) {
          const enteredAtTime = new Date(enteredAt).getTime();
          const now = Date.now();
          const timeDiff = now - enteredAtTime;
          
          if (timeDiff < 3600000) {
            timeInStage = `${Math.floor(timeDiff / 60000)}m`;
          } else if (timeDiff < 86400000) {
            timeInStage = `${Math.floor(timeDiff / 3600000)}h`;
          } else {
            timeInStage = `${Math.floor(timeDiff / 86400000)}d`;
          }
        }

        return {
          id: attribute.id,
          pipelineName: attribute.attribute_display_name,
          stageName,
          displayText,
          statusType,
          statusDate,
          dealValue: dealValue || 0,
          timeInStage,
        };
      }).filter(Boolean); // Remove nulls
    },
    // Verificar se há etapas para mostrar
    hasKanbanStages() {
      return this.kanbanStages.length > 0;
    },
  },
  watch: {
    kanbanStages() {
      this.$nextTick(() => this.computeVisibleStagePosition());
    },
  },
  mounted() {
    this.computeVisibleStagePosition();
    
    // Escutar eventos de atualização de attributes para atualizar os nomes das etapas
    if (window.bus) {
      window.bus.$on('attributes:updated', this.handleAttributesUpdate);
    }
  },
  beforeDestroy() {
    // Limpar listener
    if (window.bus) {
      window.bus.$off('attributes:updated', this.handleAttributesUpdate);
    }
  },
  methods: {
    kanbanLinkForStage(stage) {
      if (!this.contact?.id || !stage?.id) {
        return { name: 'kanban_view', params: { accountId: String(this.accountId) } };
      }
      return buildKanbanDeepLink(this.accountId, {
        contactId: this.contact.id,
        pipelineId: stage.id,
      });
    },
    formatCurrency(value) {
      if (!value) return '';
      // Simples formatação de moeda - pode ser melhorada conforme necessário
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
      }).format(value);
    },
    formatDate(dateString) {
      if (!dateString) return '';
      
      try {
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('pt-BR', {
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        }).format(date);
      } catch (error) {
        return dateString;
      }
    },
    handleAttributesUpdate() {
      // Forçar re-render quando attributes são atualizados
      this.$forceUpdate();
    },
    onShowStages(e) {
      e.stopPropagation();
      this.showAllStages = !this.showAllStages;
      this.$nextTick(() => this.computeVisibleStagePosition());
    },
    computeVisibleStagePosition() {
      const stageContainer = this.$refs.stageContainer;
      if (!stageContainer) return;

      // Temporariamente mostrar todas para medir largura real
      const wasShowingAll = this.showAllStages;
      if (!wasShowingAll) {
        this.showAllStages = true;
        this.$nextTick(() => {
          this.calculateWithFixedWidth();
          this.showAllStages = false;
        });
        return;
      }
      
      this.calculateWithFixedWidth();
    },
    calculateWithFixedWidth() {
      const stageContainer = this.$refs.stageContainer;
      if (!stageContainer) return;

      // Usar largura fixa do container para cálculos estáveis
      const containerWidth = stageContainer.clientWidth;
      const stages = Array.from(
        stageContainer.querySelectorAll('a.tooltip-container, .tooltip-container')
      );
      
      if (stages.length === 0) return;
      
      let stageOffset = 0;
      let newStagePosition = stages.length - 1;
      let newShowExpandButton = false;
      
      stages.forEach((stage, index) => {
        stageOffset += stage.offsetWidth + 4; // 4px é o gap entre as pílulas
        if (stageOffset > containerWidth - 40) { // 40px para o botão de expandir
          if (newStagePosition === stages.length - 1) {
            newStagePosition = Math.max(0, index - 1);
            newShowExpandButton = stages.length > 1;
          }
        }
      });
      
      this.stagePosition = newStagePosition;
      this.showExpandButton = newShowExpandButton;
    },
  },
};
</script>

<style scoped>
.tooltip-container {
  position: relative;
}

.tooltip-content {
  position: absolute;
  top: calc(100% + 0.5rem);
  left: 50%;
  transform: translateX(-50%);
  z-index: 50;
  padding: 0.75rem 1rem;
  font-size: 0.75rem;
  background-color: #1e293b;
  color: white;
  border-radius: 0.5rem;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  max-width: 20rem;
  white-space: normal;
  opacity: 0;
  visibility: hidden;
  transition: opacity 0.15s ease-in-out, visibility 0.15s ease-in-out;
  pointer-events: none;
}

.tooltip-arrow {
  position: absolute;
  top: -0.25rem;
  left: 50%;
  transform: translateX(-50%) rotate(45deg);
  width: 0.5rem;
  height: 0.5rem;
  background-color: #1e293b;
}

/* Hover na pílula inteira */
.tooltip-container:hover .tooltip-content {
  opacity: 1;
  visibility: visible;
}

/* Hover no tooltip também */
.tooltip-content:hover {
  opacity: 1;
  visibility: visible;
}

.show-more--button {
  height: 1.25rem;
}

.show-more--button.secondary:focus {
  color: #374151;
  border-color: #d1d5db;
}

.dark .show-more--button.secondary:focus {
  color: #e5e7eb;
  border-color: #374151;
}

.hidden {
  visibility: hidden;
  position: absolute;
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
  .tooltip-content {
    background-color: #0f172a;
  }
  
  .tooltip-arrow {
    background-color: #0f172a;
  }
}
</style>
