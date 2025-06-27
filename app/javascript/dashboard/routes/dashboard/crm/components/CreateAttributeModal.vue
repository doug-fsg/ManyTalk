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
          <div class="stages-list">
            <div 
              v-for="(stage, index) in stages" 
              :key="index"
              class="stage-item"
            >
              <woot-input
                v-model.trim="stage.name"
                :placeholder="$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.PLACEHOLDER')"
                class="stage-input"
              />
              <span 
                v-if="stages.length > 1"
                class="remove-stage"
                @click="removeStage(index)"
              >
                <fluent-icon icon="dismiss" size="16" />
              </span>
            </div>
          </div>
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
            {{ $t('GENERAL.CANCEL') }}
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
import { required, minLength } from 'vuelidate/lib/validators';
import { convertToAttributeSlug } from 'dashboard/helper/commons.js';

export default {
  name: 'CreateAttributeModal',
  components: {
    Multiselect,
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
      minLength: minLength(10)
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
          attribute_values: validStages
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
  padding: var(--space-normal);
  min-width: 400px;
  max-width: 600px;
}

.attribute-form {
  margin-top: var(--space-normal);
  
  .stages-section {
    margin: var(--space-medium) 0;
    
    .stages-label {
      display: block;
      margin-bottom: var(--space-small);
      font-size: var(--font-size-small);
      color: var(--s-700);
    }
    
    .stages-list {
      display: flex;
      flex-direction: column;
      gap: var(--space-small);
    }
    
    .stage-item {
      display: flex;
      align-items: center;
      gap: var(--space-small);
      
      .stage-input {
        flex: 1;
      }
      
      .remove-stage {
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
    
    .add-stage-btn {
      margin-top: var(--space-small);
      display: inline-flex;
      align-items: center;
      gap: var(--space-smaller);
    }
  }
  
  .modal-footer {
    margin-top: var(--space-medium);
    display: flex;
    justify-content: flex-end;
    gap: var(--space-small);
  }
}
</style> 