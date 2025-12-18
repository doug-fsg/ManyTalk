<template>
  <div class="kanban-stage-select">
    <div class="multiselect-wrap--small">
      <multiselect
        v-model="selectedPipeline"
        track-by="id"
        label="name"
        :placeholder="$t('MACROS.KANBAN.SELECT_PIPELINE')"
        :max-height="160"
        :options="pipelineOptions"
        :allow-empty="false"
        :disabled="pipelineOptions.length === 0"
        @input="onPipelineChange"
      />
    </div>
    <div v-if="selectedPipeline" class="multiselect-wrap--small">
      <multiselect
        v-model="selectedStage"
        track-by="id"
        label="name"
        :placeholder="$t('MACROS.KANBAN.SELECT_STAGE')"
        :max-height="160"
        :options="stageOptions"
        :allow-empty="false"
        :disabled="stageOptions.length === 0"
        @input="updateValue"
      />
    </div>
    
    <!-- Mensagens de erro informativas -->
    <div v-if="pipelineOptions.length === 0" class="kanban-error-message">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        {{ $t('MACROS.KANBAN.NO_PIPELINES') }}
      </p>
    </div>
    
    <div v-if="selectedPipeline && stageOptions.length === 0" class="kanban-error-message">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        {{ $t('MACROS.KANBAN.NO_STAGES') }}
      </p>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    value: {
      type: Array,
      default: () => []
    }
  },
  data() {
    return {
      selectedPipeline: null,
      selectedStage: null,
      pipelineOptions: [],
      stageOptions: []
    };
  },
  mounted() {
    this.loadPipelineOptions();
    
    // Carregar valores existentes se houver
    if (this.value && this.value.length >= 2) {
      const [pipelineData, stageData] = this.value;
      this.loadExistingValues(pipelineData, stageData);
    }
  },
  methods: {
    loadPipelineOptions() {
      try {
        const kanbanAttributes = this.$store.getters['attributes/getAttributes']
          .filter(attr => attr.attribute_model === 'contact_attribute' && attr.is_kanban === true);
        
        this.pipelineOptions = kanbanAttributes.map(attr => ({
          id: attr.id,
          name: attr.attribute_display_name,
          attribute_key: attr.attribute_key,
          stages: attr.attribute_values || []
        }));
      } catch (error) {
        this.pipelineOptions = [];
      }
    },
    
    loadExistingValues(pipelineData, stageData) {
      // Converter os dados para o formato esperado
      let pipelineId, stageName;
      
      // Extrair ID do pipeline
      if (typeof pipelineData === 'object' && pipelineData !== null && pipelineData.id) {
        pipelineId = pipelineData.id;
      } else {
        pipelineId = pipelineData;
      }
      
      // Extrair nome do estágio
      if (typeof stageData === 'object' && stageData !== null) {
        // Se é objeto, usar o id ou name como nome do estágio
        stageName = stageData.id || stageData.name || String(stageData);
      } else {
        stageName = stageData;
      }
      
      const pipeline = this.pipelineOptions.find(p => p.id.toString() === pipelineId.toString());
      if (pipeline) {
        this.selectedPipeline = pipeline;
        // Passar skipUpdate = true para não limpar o selectedStage
        this.onPipelineChange(pipeline, true);
        
        // Buscar o estágio correspondente pelo nome
        const stage = this.stageOptions.find(s => {
          // Comparar por nome (case-insensitive para maior robustez)
          return s.name && stageName && 
                 s.name.toString().toLowerCase() === stageName.toString().toLowerCase();
        });
        
        if (stage) {
          this.selectedStage = stage;
        }
      }
    },
    
    onPipelineChange(pipeline, skipUpdate = false) {
      if (!pipeline || !pipeline.stages) {
        this.stageOptions = [];
        this.selectedStage = null;
        return;
      }
      
      // Normalizar os stages para lidar com diferentes formatos:
      // - String simples (formato legado): "Matrícula"
      // - Objeto com name e color (formato novo): {name: "Matrícula", color: "#ff6900"}
      this.stageOptions = pipeline.stages.map((stage, index) => {
        let stageName;
        let stageColor = null;
        
        if (typeof stage === 'string') {
          // Formato legado: string simples
          stageName = stage;
        } else if (typeof stage === 'object' && stage !== null) {
          // Formato novo: objeto com name e color
          stageName = stage.name || stage.id || String(stage);
          stageColor = stage.color || null;
        } else {
          // Fallback: converter para string
          stageName = String(stage);
        }
        
        return {
          id: index,
          name: stageName,
          color: stageColor,
          pipeline_id: pipeline.id
        };
      });
      
      // Limpar seleção de estágio anterior apenas se não estivermos carregando valores existentes
      if (!skipUpdate) {
        this.selectedStage = null;
        this.updateValue();
      }
    },
    
    updateValue() {
      if (!this.selectedPipeline || !this.selectedStage) {
        this.$emit('input', []);
        return;
      }
      
      // Enviar no formato que o actionQueryGenerator espera
      const value = [
        { id: this.selectedPipeline.id, name: this.selectedPipeline.name },
        { id: this.selectedStage.name, name: this.selectedStage.name }
      ];
      this.$emit('input', value);
    }
  }
};
</script>

<style scoped>
.kanban-stage-select {
  @apply space-y-2;
}

.multiselect {
  @apply mb-2;
}

.kanban-error-message {
  @apply mt-2 p-2 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-md;
}

.kanban-error-message p {
  @apply m-0;
}
</style>
