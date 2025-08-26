<template>
  <woot-modal
    :show.sync="show"
    :on-close="onClose"
  >
    <div class="create-attribute-modal">
      <woot-modal-header
        :header-title="$t('KANBAN.CREATE_PIPELINE.TITLE')"
        :header-content="$t('KANBAN.CREATE_PIPELINE.DESCRIPTION')"
      />
      
      <form class="attribute-form" @submit.prevent="createAttribute">
        <woot-input
          v-model.trim="displayName"
          :label="$t('KANBAN.CREATE_PIPELINE.FORM.NAME.LABEL')"
          :placeholder="$t('KANBAN.CREATE_PIPELINE.FORM.NAME.PLACEHOLDER')"
          :error="displayNameError"
          @input="$v.displayName.$touch"
        />
        
        <woot-input
          v-model.trim="description"
          :label="$t('KANBAN.CREATE_PIPELINE.FORM.DESCRIPTION.LABEL')"
          :placeholder="$t('KANBAN.CREATE_PIPELINE.FORM.DESCRIPTION.PLACEHOLDER')"
          :error="descriptionError"
          @input="$v.description.$touch"
        />
        
        <div class="stages-section">
          <label class="stages-label">
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.STAGES.LABEL') }}
          </label>
          <p class="stages-helper-text">
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.STAGES.HELPER') }}
          </p>
          <draggable
            v-model="stages"
            class="stages-list"
            animation="200"
            ghost-class="stage-ghost"
            handle=".drag-handle"
            @end="onStageReorder"
          >
            <div 
              v-for="(stage, index) in stages" 
              :key="index"
              class="stage-item"
            >
              <div class="drag-handle" :title="$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.DRAG_HINT')">
                <fluent-icon icon="drag" size="16" />
              </div>
              <div class="stage-number">{{ index + 1 }}</div>
              <woot-input
                v-model.trim="stage.name"
                :placeholder="$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.PLACEHOLDER')"
                class="stage-input"
              />
              <button 
                v-if="stages.length > 1"
                type="button"
                class="remove-stage"
                :title="$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.REMOVE_HINT')"
                @click="removeStage(index)"
              >
                <fluent-icon icon="dismiss" size="16" />
              </button>
            </div>
          </draggable>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            class="add-stage-btn"
            @click="addStage"
          >
            <fluent-icon icon="add" size="16" />
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.STAGES.ADD') }}
          </woot-button>
        </div>
        
        <div class="modal-footer">
          <woot-button
            variant="clear"
            @click="onClose"
          >
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.CANCEL') }}
          </woot-button>
          <woot-button
            variant="primary"
            type="submit"
            :is-loading="isCreating"
            :disabled="isButtonDisabled"
          >
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.CREATE') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<script>
import Multiselect from 'vue-multiselect';
import draggable from 'vuedraggable';
import { required, minLength } from 'vuelidate/lib/validators';
import { convertToAttributeSlug } from 'dashboard/helper/commons.js';

export default {
  name: 'CreateAttributeModal',
  components: {
    Multiselect,
    draggable,
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
        { name: '' },
        { name: '' }
      ],
      isCreating: false
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
    displayNameError() {
      if (this.$v.displayName.$error) {
        return this.$t('KANBAN.CREATE_PIPELINE.FORM.NAME.ERROR');
      }
      return '';
    },
    descriptionError() {
      if (this.$v.description.$error) {
        return this.$t('KANBAN.CREATE_PIPELINE.FORM.DESCRIPTION.ERROR');
      }
      return '';
    },
    isButtonDisabled() {
      return (
        this.$v.$invalid ||
        this.isCreating ||
        !this.stages.some(stage => stage.name.trim())
      );
    }
  },
  methods: {
    addStage() {
      this.stages.push({ name: '' });
    },
    removeStage(index) {
      this.stages.splice(index, 1);
    },
    onStageReorder() {
      // A reatividade do Vue atualiza automaticamente os números dos estágios
      // quando o array stages é reordenado pelo vuedraggable
    },
    onClose() {
      this.resetForm();
      this.$emit('update:show', false);
    },
    resetForm() {
      this.displayName = '';
      this.description = '';
      this.stages = [{ name: '' }, { name: '' }];
      this.$v.$reset();
    },
    async createAttribute() {
      try {
        this.isCreating = true;
        
        // Filtrar estágios vazios
        const validStages = this.stages
          .map(stage => stage.name.trim())
          .filter(Boolean);
        
        if (!validStages.length) {
          throw new Error(this.$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.ERROR'));
        }
        
        const attributeData = {
          attribute_display_name: this.displayName,
          attribute_description: this.description,
          attribute_display_type: 'list',
          attribute_key: convertToAttributeSlug(this.displayName),
          attribute_model: 'contact_attribute',
          attribute_values: validStages,
          is_kanban: true  // Marcar automaticamente como Kanban
        };
        
        await this.$store.dispatch('attributes/create', attributeData);
        
        this.$emit('attribute-created', attributeData);
        this.resetForm();
      } catch (error) {
        this.$emit('create-error', error);
      } finally {
        this.isCreating = false;
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.create-attribute-modal {
  @apply p-6 min-w-[400px] max-w-[600px] bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100;
  padding: var(--space-normal);
  min-width: 400px;
  max-width: 600px;
}

.attribute-form {
  @apply mt-4 text-slate-900 dark:text-slate-100;
  margin-top: var(--space-normal);
  
  .stages-section {
    @apply my-4;
    margin: var(--space-medium) 0;
    
    .stages-label {
      @apply block mb-2 text-sm font-medium text-slate-700 dark:text-slate-300;
      display: block;
      margin-bottom: var(--space-small);
      font-size: var(--font-size-small);
      color: var(--s-700);
    }
    
    .stages-helper-text {
      @apply text-xs text-slate-500 dark:text-slate-400 mb-3 italic;
    }
    
    .stages-list {
      @apply flex flex-col gap-3;
      display: flex;
      flex-direction: column;
      gap: var(--space-small);
    }
    
    .stage-item {
      @apply flex items-center gap-2 sm:gap-3 p-2 sm:p-3 bg-slate-50 dark:bg-slate-700 rounded-lg border border-slate-200 dark:border-slate-600 transition-all duration-200;
      display: flex;
      align-items: center;
      gap: var(--space-small);
      
      &:hover {
        @apply bg-slate-100 dark:bg-slate-600 border-slate-300 dark:border-slate-500;
      }
      
      .drag-handle {
        @apply cursor-grab text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300 transition-colors p-1 rounded;
        
        &:hover {
          @apply bg-slate-200 dark:bg-slate-600;
        }
        
        &:active {
          @apply cursor-grabbing;
        }
      }
      
      .stage-number {
        @apply flex items-center justify-center w-6 h-6 bg-slate-200 dark:bg-slate-600 text-slate-700 dark:text-slate-200 text-xs font-medium rounded-full;
      }
      
      .stage-input {
        @apply flex-1;
        flex: 1;
      }
      
      .remove-stage {
        @apply cursor-pointer text-slate-500 dark:text-slate-400 p-2 rounded-lg hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/30 transition-all duration-200 border-0 bg-transparent;
        cursor: pointer;
        color: var(--s-500);
        padding: var(--space-smaller);
        border-radius: var(--border-radius-small);
        
        &:hover {
          color: var(--r-500);
          background-color: var(--s-50);
        }
      }
    }
    
    // Estado ghost durante o drag
    .stage-ghost {
      @apply opacity-50 bg-slate-100 dark:bg-slate-700/50 border-slate-300 dark:border-slate-500 border-dashed;
    }
    
    // Estado sortable durante o drag
    .sortable-chosen {
      @apply shadow-lg scale-105 z-10;
    }
    
    .sortable-drag {
      @apply opacity-80;
    }
    
    .add-stage-btn {
      @apply mt-2 inline-flex items-center gap-1;
      margin-top: var(--space-small);
      display: inline-flex;
      align-items: center;
      gap: var(--space-smaller);
    }
  }
  
  .modal-footer {
    @apply mt-4 flex justify-end gap-2 pt-4 border-t border-slate-200 dark:border-slate-600;
    margin-top: var(--space-medium);
    display: flex;
    justify-content: flex-end;
    gap: var(--space-small);
  }
}
</style> 