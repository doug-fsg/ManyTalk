<template>
  <woot-modal
    :show="show" @update:show="$emit('update:show', $event)"
    :on-close="onClose"
    size="medium"
    :full-width="false"
  >
    <div class="create-pipeline-container">
      <!-- Header -->
      <div class="flex flex-col items-start px-12 pt-8 pb-0 flex-shrink-0">
        <div class="flex items-center justify-between w-full gap-4">
          <div class="flex items-center gap-3 flex-wrap">
            <h2 class="text-base font-semibold leading-6 text-slate-800 dark:text-slate-50">
              {{ $t('KANBAN.CREATE_PIPELINE.TITLE') }}
            </h2>
          </div>
        </div>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-2">
          {{ $t('KANBAN.CREATE_PIPELINE.DESCRIPTION') }}
        </p>
      </div>

      <!-- Layout de Duas Colunas -->
      <form class="flex w-full flex-1 min-h-0" @submit.prevent="createAttribute">
        <!-- Coluna Esquerda -->
        <div class="w-2/5 px-4 py-4 space-y-6">
          <!-- Dados Básicos -->
          <div class="basic-data-section">
            <!-- Header colapsável -->
            <div 
              class="section-header"
              @click="basicDataExpanded = !basicDataExpanded"
            >
              <div class="header-left">
                <fluent-icon 
                  :icon="basicDataExpanded ? 'chevron-down' : 'chevron-right'" 
                  size="16" 
                  class="chevron-icon"
                />
                <fluent-icon icon="document" size="16" class="document-icon" />
                <h3 class="section-title">Dados Básicos</h3>
              </div>
              <fluent-icon 
                icon="chevron-down" 
                size="16" 
                class="expand-icon"
                :class="{ 'rotate-180': basicDataExpanded }"
              />
            </div>

            <!-- Conteúdo expansível -->
            <div v-if="basicDataExpanded" class="section-content">
              <woot-input
                v-model.trim="displayName"
                :label="$t('KANBAN.CREATE_PIPELINE.FORM.NAME.LABEL')"
                type="text"
                :class="{ error: $v.displayName.$error }"
                :error="
                  $v.displayName.$error
                    ? $t('KANBAN.CREATE_PIPELINE.FORM.NAME.ERROR')
                    : ''
                "
                :placeholder="$t('KANBAN.CREATE_PIPELINE.FORM.NAME.PLACEHOLDER')"
                @blur="$v.displayName.$touch"
                @input="$v.displayName.$touch"
                aria-required="true"
                :aria-invalid="$v.displayName.$error"
              />

              <div class="mt-4">
                <label class="block mb-1.5 text-sm font-medium text-slate-700 dark:text-slate-300" for="pipeline-description">
                  {{ $t('KANBAN.CREATE_PIPELINE.FORM.DESCRIPTION.LABEL') }}
                  <span class="text-red-500 dark:text-red-400 ml-0.5" aria-label="obrigatório">*</span>
                </label>
                <textarea
                  id="pipeline-description"
                  v-model.trim="description"
                  rows="4"
                  class="w-full px-3 py-2 text-sm border rounded-lg bg-white dark:bg-slate-900 text-slate-900 dark:text-white resize-none transition-colors focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent"
                  :class="$v.description.$error ? 'border-red-500 dark:border-red-400 focus:ring-red-500 dark:focus:ring-red-400' : 'border-slate-200 dark:border-slate-600'"
                  :placeholder="$t('KANBAN.CREATE_PIPELINE.FORM.DESCRIPTION.PLACEHOLDER')"
                  @blur="$v.description.$touch"
                  @input="$v.description.$touch"
                  aria-required="true"
                  :aria-invalid="$v.description.$error"
                  :aria-describedby="$v.description.$error ? 'desc-error' : null"
                />
                <span 
                  v-if="$v.description.$error" 
                  id="desc-error"
                  class="text-red-500 dark:text-red-400 text-xs mt-1.5 font-medium block" 
                  role="alert"
                >
                  {{ $t('KANBAN.CREATE_PIPELINE.FORM.DESCRIPTION.ERROR') }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Coluna Direita (Sidebar) -->
        <div class="w-3/5 border-l border-slate-200 dark:border-slate-700">
          <!-- Etapas desse funil -->
          <div class="px-4 py-4 space-y-6">
            <div class="stages-section">
              <!-- Header colapsável -->
              <div 
                class="section-header"
                @click="stagesExpanded = !stagesExpanded"
                @keydown.enter="stagesExpanded = !stagesExpanded"
                @keydown.space.prevent="stagesExpanded = !stagesExpanded"
                role="button"
                :aria-expanded="stagesExpanded"
                aria-label="Etapas desse funil"
                tabindex="0"
              >
                <div class="header-left">
                  <fluent-icon 
                    :icon="stagesExpanded ? 'chevron-down' : 'chevron-right'" 
                    size="16" 
                    class="chevron-icon"
                  />
                  <fluent-icon icon="list" size="16" class="list-icon" />
                  <h3 class="section-title">Etapas desse funil</h3>
                  <span class="px-1.5 py-0.5 text-xs font-medium bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-400 rounded" aria-label="Total de etapas">
                    {{ stages.length }}
                  </span>
                </div>
                <fluent-icon 
                  icon="chevron-down" 
                  size="16" 
                  class="expand-icon"
                  :class="{ 'rotate-180': stagesExpanded }"
                />
              </div>

              <!-- Conteúdo expansível -->
              <div v-if="stagesExpanded" class="section-content">
                <draggable
                  v-model="stages"
                  handle=".drag-handle"
                  class="stages-list"
                  animation="150"
                  ghost-class="stage-ghost"
                >
                  <div 
                    v-for="(stage, index) in stages" 
                    :key="index"
                    class="stage-item"
                    role="listitem"
                  >
                    <div class="stage-info">
                      <div class="drag-handle" v-tooltip="'Arrastar para reordenar'">
                        <fluent-icon icon="drag" size="16" />
                      </div>
                      <!-- Edição de cor inline -->
                      <div 
                        v-if="editingColorIndex === index"
                        class="stage-color-editor"
                        @click.stop
                      >
                        <color-picker
                          :value="stage.color"
                          @input="(color) => updateStageColorInline(index, color)"
                        />
                      </div>
                      <div 
                        v-else
                        class="stage-color-indicator stage-color-clickable" 
                        :style="{ backgroundColor: stage.color }"
                        :aria-label="`Cor da etapa ${stage.name || 'nova'}`"
                        v-tooltip="'Clique para editar a cor'"
                        @click.stop="startEditingColor(index)"
                      />
                      
                      <!-- Edição de nome inline -->
                      <input
                        v-if="editingNameIndex === index"
                        :ref="`stageNameInput-${index}`"
                        v-model="editingStageName"
                        type="text"
                        class="stage-name-input"
                        @blur="finishEditingName(index)"
                        @keyup.enter="finishEditingName(index)"
                        @keyup.esc="cancelEditingName"
                      />
                      <span 
                        v-else
                        class="stage-name stage-name-clickable"
                        v-tooltip="'Clique para editar o nome'"
                        @click.stop="startEditingName(index, stage.name)"
                      >
                        {{ stage.name || 'Nova etapa' }}
                      </span>
                    </div>
                    <div class="stage-actions">
                      <button
                        type="button"
                        class="stage-action-btn"
                        v-tooltip="'Copiar'"
                        @click.stop="copyStage(index)"
                        :aria-label="`Copiar etapa ${stage.name}`"
                      >
                        <fluent-icon icon="copy" size="14" />
                      </button>
                      <button
                        v-if="stages.length > 1"
                        type="button"
                        class="stage-action-btn stage-action-btn-delete"
                        v-tooltip="'Deletar'"
                        @click.stop="removeStage(index)"
                        :aria-label="`Deletar etapa ${stage.name}`"
                      >
                        <fluent-icon icon="delete" size="14" />
                      </button>
                    </div>
                  </div>
                </draggable>
                
                <!-- Botão para adicionar nova etapa -->
                <button
                  type="button"
                  class="add-stage-btn"
                  @click="addNewStage"
                  v-tooltip="'Adicionar nova etapa'"
                >
                  <fluent-icon icon="add" size="14" />
                  <span>Adicionar etapa</span>
                </button>
              </div>
            </div>

            <!-- Agentes do Funil (apenas para administradores) -->
            <funnel-agents-permissions
              v-if="isAdministrator"
              :pipeline-id="null"
              :permissions.sync="agentPermissions"
            />
          </div>
        </div>
      </form>

      <!-- Footer com ações -->
      <div class="flex justify-end items-center gap-2 px-8 py-3 border-t border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50 flex-shrink-0">
        <woot-button 
          variant="clear" 
          type="button"
          @click="onClose"
          aria-label="Cancelar"
        >
          {{ $t('KANBAN.CREATE_PIPELINE.FORM.CANCEL') }}
        </woot-button>
        <woot-button 
          variant="primary" 
          type="button"
          :is-loading="isCreating" 
          :disabled="isButtonDisabled"
          @click="createAttribute"
          :aria-label="isButtonDisabled ? 'Criar (desabilitado - corrija os erros)' : 'Criar pipeline'"
        >
          {{ $t('KANBAN.CREATE_PIPELINE.FORM.CREATE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import draggable from 'vuedraggable';
import { required, minLength } from 'vuelidate/lib/validators';
import { convertToAttributeSlug } from 'dashboard/helper/commons.js';
import ColorPicker from 'dashboard/components/widgets/ColorPicker.vue';
import FunnelAgentsPermissions from 'dashboard/routes/dashboard/crm/components/FunnelAgentsPermissions.vue';
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';

export default {
  name: 'CreateAttributeModal',
  components: {
    draggable,
    ColorPicker,
    FunnelAgentsPermissions,
  },
  props: {
    show: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      displayName: '',
      description: '',
      stages: [
        { name: 'Etapa 1', color: '#8B5CF6' },
        { name: 'Etapa 2', color: '#3B82F6' }
      ],
      isCreating: false,
      defaultColors: [
        '#8B5CF6', // violet
        '#3B82F6', // blue
        '#10B981', // green
        '#F59E0B', // amber
        '#EF4444', // red
        '#EC4899', // pink
        '#6366F1', // indigo
        '#14B8A6', // teal
      ],
      colorMap: {},
      editingColorIndex: null,
      editingNameIndex: null,
      editingStageName: '',
      basicDataExpanded: true,
      stagesExpanded: true,
      agentPermissions: {},
    };
  },
  validations: {
    displayName: {
      required,
      minLength: minLength(2)
    },
    description: {
      required,
      minLength: minLength(3)
    }
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      currentRole: 'getCurrentRole',
    }),
    isAdministrator() {
      return this.currentRole === 'administrator';
    },
    isButtonDisabled() {
      return (
        this.$v.$invalid ||
        this.isCreating ||
        !this.stages.some(stage => stage.name && stage.name.trim())
      );
    }
  },
  mounted() {
    document.addEventListener('click', this.handleDocumentClick);
  },
  beforeDestroy() {
    document.removeEventListener('click', this.handleDocumentClick);
  },
  methods: {
    addNewStage() {
      // Garantir que a sanfona esteja aberta
      if (!this.stagesExpanded) {
        this.stagesExpanded = true;
      }
      
      // Gerar nome único para nova etapa
      let stageNumber = this.stages.length + 1;
      let newName = `Etapa ${stageNumber}`;
      
      while (this.stages.some(stage => stage.name.toLowerCase() === newName.toLowerCase())) {
        stageNumber++;
        newName = `Etapa ${stageNumber}`;
      }
      
      // Selecionar próxima cor do array de cores padrão
      const nextColorIndex = this.stages.length % this.defaultColors.length;
      
      // Adicionar nova etapa na lista
      const newStage = {
        name: newName,
        color: this.defaultColors[nextColorIndex],
      };
      
      this.stages.push(newStage);
      this.colorMap[newName] = newStage.color;
      
      // Abrir edição do nome automaticamente
      const newIndex = this.stages.length - 1;
      this.$nextTick(() => {
        this.startEditingName(newIndex, newName);
      });
    },
    copyStage(index) {
      const stage = this.stages[index];
      const copiedStage = {
        name: `${stage.name} (cópia)`,
        color: stage.color,
      };
      this.stages.splice(index + 1, 0, copiedStage);
      // Atualizar colorMap para a cópia
      this.colorMap[copiedStage.name] = copiedStage.color;
      useAlert(`Etapa "${copiedStage.name}" copiada com sucesso!`);
    },
    removeStage(index) {
      const stageName = this.stages[index].name;
      this.stages.splice(index, 1);
      useAlert(`Etapa "${stageName}" removida com sucesso!`);
    },
    startEditingColor(index) {
      this.editingColorIndex = index;
      // Fechar edição de nome se estiver aberta
      if (this.editingNameIndex !== null) {
        this.editingNameIndex = null;
      }
    },
    updateStageColorInline(index, color) {
      if (this.stages[index]) {
        this.$set(this.stages[index], 'color', color);
        this.$set(this.colorMap, this.stages[index].name, color);
      }
    },
    handleDocumentClick(event) {
      // Verificar se o clique foi no color picker ou no chrome picker
      const colorPicker = event.target.closest('.colorpicker');
      const chromePicker = event.target.closest('.colorpicker--chrome');
      
      if (!colorPicker && !chromePicker) {
        // Clique foi fora, fechar edição
        this.editingColorIndex = null;
      }
    },
    startEditingName(index, currentName) {
      this.editingNameIndex = index;
      this.editingStageName = currentName;
      // Fechar edição de cor se estiver aberta
      if (this.editingColorIndex !== null) {
        this.editingColorIndex = null;
      }
      // Focar no input
      this.$nextTick(() => {
        const inputRef = `stageNameInput-${index}`;
        const input = this.$refs[inputRef];
        if (input && input.length) {
          input[0].focus();
          input[0].select();
        } else if (input) {
          input.focus();
          input.select();
        }
      });
    },
    finishEditingName(index) {
      if (this.editingStageName && this.editingStageName.trim()) {
        const oldName = this.stages[index].name;
        const newName = this.editingStageName.trim();
        
        // Verificar se o nome já existe
        const nameExists = this.stages.some((stage, i) => 
          i !== index && stage.name.toLowerCase() === newName.toLowerCase()
        );
        
        if (nameExists) {
          useAlert('Já existe uma etapa com este nome!');
          this.editingStageName = oldName;
          return;
        }
        
        this.$set(this.stages[index], 'name', newName);
        
        // Atualizar colorMap
        if (this.colorMap[oldName]) {
          const color = this.colorMap[oldName];
          delete this.colorMap[oldName];
          this.colorMap[newName] = color;
        }
      }
      this.editingNameIndex = null;
      this.editingStageName = '';
    },
    cancelEditingName() {
      this.editingNameIndex = null;
      this.editingStageName = '';
    },
    onClose() {
      this.resetForm();
      this.$emit('update:show', false);
    },
    resetForm() {
      this.displayName = '';
      this.description = '';
      this.stages = [
        { name: 'Etapa 1', color: '#8B5CF6' }, 
        { name: 'Etapa 2', color: '#3B82F6' }
      ];
      this.colorMap = {};
      this.editingColorIndex = null;
      this.editingNameIndex = null;
      this.editingStageName = '';
      this.basicDataExpanded = true;
      this.stagesExpanded = true;
      this.agentPermissions = {};
      this.$v.$reset();
    },
    async createAttribute() {
      this.$v.$touch();
      if (this.$v.$invalid) {
        return;
      }
      
      try {
        this.isCreating = true;
        
        // Filtrar estágios vazios e criar objeto no formato novo
        const validStages = this.stages
          .filter(stage => stage.name && stage.name.trim())
          .reduce((acc, stage) => {
            acc[stage.name.trim()] = {
              color: stage.color || '#8B5CF6'
            };
            return acc;
          }, {});
        
        if (Object.keys(validStages).length === 0) {
          throw new Error(this.$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.ERROR'));
        }
        
        // Formato: { stages: { "nome": { color }, ... }, permissions: {} }
        const attributeValues = {
          stages: validStages,
          permissions: this.agentPermissions || {}
        };
        
        const attributeData = {
          attribute_display_name: this.displayName,
          attribute_description: this.description,
          attribute_display_type: 'list',
          attribute_key: convertToAttributeSlug(this.displayName),
          attribute_model: 'contact_attribute',
          attribute_values: attributeValues,
          is_kanban: true  // Marcar automaticamente como Kanban
        };
        
        await this.$store.dispatch('attributes/create', attributeData);
        
        useAlert('Pipeline criado com sucesso!');
        this.$emit('attribute-created', attributeData);
        this.resetForm();
        this.$emit('update:show', false);
      } catch (error) {
        const errorMessage = error?.message || 'Erro ao criar pipeline';
        useAlert(errorMessage);
        this.$emit('create-error', error);
      } finally {
        this.isCreating = false;
      }
    },
  },
};
</script>

<style scoped lang="scss">
.create-pipeline-container {
  @apply flex flex-col;
  height: 80vh;
  max-height: 800px;
  min-height: 600px;
  overflow: hidden;
}

.create-pipeline-container > form {
  @apply flex-1 min-h-0 overflow-y-auto overflow-x-hidden;
  flex: 1 1 auto;
  min-height: 0;
}

.basic-data-section {
  @apply border border-slate-200 dark:border-slate-600 rounded-xl;
  overflow: visible !important;
}

.stages-section {
  @apply border border-slate-200 dark:border-slate-600 rounded-xl;
  overflow: visible !important;
}

.section-header {
  @apply flex items-center justify-between px-4 py-3 cursor-pointer;
  @apply bg-slate-50 dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 ease-smooth;
  @apply transition-colors duration-200;

  .header-left {
    @apply flex items-center gap-2;
  }

  .chevron-icon,
  .list-icon,
  .document-icon {
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
  @apply p-3 space-y-2 bg-white dark:bg-slate-900;
  overflow: visible !important;
}

.stages-list {
  @apply space-y-2;
  
  // Estados durante o drag
  .stage-ghost {
    @apply opacity-50;
  }
  
  .sortable-drag {
    @apply opacity-0;
  }
}

.stage-item {
  @apply flex items-center justify-between gap-3 py-2 px-3 rounded-lg;
  @apply bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700;
  @apply transition-all duration-200;

  &:hover {
    @apply bg-slate-100 dark:bg-slate-700;
  }
}

.stage-info {
  @apply flex items-center gap-3 flex-1 min-w-0;
}

.drag-handle {
  @apply cursor-grab active:cursor-grabbing text-slate-400 dark:text-slate-500;
  @apply hover:text-slate-600 dark:hover:text-slate-300 transition-colors;
  @apply flex-shrink-0;
  
  &:active {
    @apply cursor-grabbing;
  }
}

.stage-color-indicator {
  @apply w-2 h-2 rounded-full flex-shrink-0;
  
  &.stage-color-clickable {
    @apply cursor-pointer transition-all duration-200;
    
    &:hover {
      @apply scale-150;
    }
  }
}

.stage-color-editor {
  @apply flex-shrink-0 relative;
  
  // Garantir que o color picker possa sair para fora
  ::v-deep .colorpicker--chrome {
    z-index: 10000 !important;
  }
}

.stage-name {
  @apply text-sm font-medium text-slate-900 dark:text-white;
  
  &.stage-name-clickable {
    @apply cursor-text px-1 py-0.5 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 ease-smooth;
    @apply transition-colors duration-200;
  }
}

.stage-name-input {
  @apply flex-1 px-2 py-1 text-sm border border-woot-500 dark:border-woot-400 rounded;
  @apply bg-white dark:bg-slate-800 text-slate-900 dark:text-white;
  @apply focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent;
}

.stage-actions {
  @apply flex items-center gap-2;
}

.stage-action-btn {
  @apply p-1.5 rounded-lg text-slate-400 dark:text-slate-500;
  @apply hover:bg-slate-50 dark:hover:bg-slate-700 hover:text-slate-600 dark:hover:text-slate-300;
  @apply transition-all duration-200 cursor-pointer flex-shrink-0;
  @apply bg-transparent border-none;

  &.stage-action-btn-delete {
    @apply hover:bg-red-50 dark:hover:bg-red-900/20 hover:text-red-500 dark:hover:text-red-400;
  }
}

.add-stage-btn {
  @apply flex items-center gap-1.5 px-3 py-1.5 mt-2 text-xs font-medium;
  @apply text-slate-600 dark:text-slate-400 hover:text-woot-600 dark:hover:text-woot-400;
  @apply bg-transparent border border-dashed border-slate-300 dark:border-slate-600;
  @apply rounded-lg hover:border-woot-500 dark:hover:border-woot-400;
  @apply hover:bg-woot-50 dark:hover:bg-woot-900/20;
  @apply transition-all duration-200 cursor-pointer;
  @apply w-full justify-center;
}

// Garantir que tooltips apareçam acima do modal
::v-deep .tooltip {
  z-index: 10001 !important;
}

::v-deep .v-tooltip-container {
  z-index: 10001 !important;
}
</style>

<style lang="scss">
/* Estilos não escoped para afetar elementos fora do componente (tooltips no body) */
body > .tooltip {
  z-index: 10001 !important;
}

body > .v-tooltip-container {
  z-index: 10001 !important;
}
</style>
