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
        console.log('[KANBAN-STAGE-SELECT] Carregando opções de pipeline');
        
        const kanbanAttributes = this.$store.getters['attributes/getAttributes']
          .filter(attr => attr.attribute_model === 'contact_attribute' && attr.is_kanban === true);
        
        this.pipelineOptions = kanbanAttributes.map(attr => ({
          id: attr.id,
          name: attr.attribute_display_name,
          attribute_key: attr.attribute_key,
          stages: attr.attribute_values || []
        }));
        
        console.log('[KANBAN-STAGE-SELECT] Pipelines carregados:', {
          total: this.pipelineOptions.length,
          options: this.pipelineOptions
        });
      } catch (error) {
        console.error('[KANBAN-STAGE-SELECT] Erro ao carregar pipelines:', error);
        this.pipelineOptions = [];
      }
    },
    
    loadExistingValues(pipelineData, stageData) {
      console.log('[KANBAN-STAGE-SELECT] Carregando valores existentes:', { pipelineData, stageData });
      
      // Se os dados estão no formato antigo [id, name], converter
      let pipelineId, stageName;
      if (typeof pipelineData === 'object' && pipelineData.id) {
        pipelineId = pipelineData.id;
      } else {
        pipelineId = pipelineData;
      }
      
      if (typeof stageData === 'object' && stageData.id) {
        stageName = stageData.id; // Para stages, o id é o nome
      } else {
        stageName = stageData;
      }
      
      const pipeline = this.pipelineOptions.find(p => p.id.toString() === pipelineId.toString());
      if (pipeline) {
        this.selectedPipeline = pipeline;
        this.onPipelineChange(pipeline);
        
        const stage = this.stageOptions.find(s => s.name === stageName);
        if (stage) {
          this.selectedStage = stage;
          this.updateValue();
        }
      }
    },
    
    onPipelineChange(pipeline) {
      console.log('[KANBAN-STAGE-SELECT] Pipeline selecionado:', pipeline);
      
      if (!pipeline || !pipeline.stages) {
        this.stageOptions = [];
        this.selectedStage = null;
        return;
      }
      
      this.stageOptions = pipeline.stages.map((stage, index) => ({
        id: index,
        name: stage,
        pipeline_id: pipeline.id
      }));
      
      console.log('[KANBAN-STAGE-SELECT] Estágios carregados:', {
        pipeline: pipeline.name,
        stages: this.stageOptions
      });
      
      // Limpar seleção de estágio anterior
      this.selectedStage = null;
      this.updateValue();
    },
    
    updateValue() {
      if (!this.selectedPipeline || !this.selectedStage) {
        console.log('[KANBAN-STAGE-SELECT] Valores incompletos, não emitindo update');
        this.$emit('input', []);
        return;
      }
      
      // Enviar no formato que o actionQueryGenerator espera
      const value = [
        { id: this.selectedPipeline.id, name: this.selectedPipeline.name },
        { id: this.selectedStage.name, name: this.selectedStage.name }
      ];
      console.log('[KANBAN-STAGE-SELECT] Emitindo valor:', value);
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
