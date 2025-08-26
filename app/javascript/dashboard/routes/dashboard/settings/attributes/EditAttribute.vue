<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="flex flex-col w-full" @submit.prevent="editAttributes">
      <div class="w-full">
        <woot-input
          v-model.trim="displayName"
          :label="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.LABEL')"
          type="text"
          :class="{ error: $v.displayName.$error }"
          :error="
            $v.displayName.$error
              ? $t('ATTRIBUTES_MGMT.ADD.FORM.NAME.ERROR')
              : ''
          "
          :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
          @blur="$v.displayName.$touch"
        />

        <label :class="{ error: $v.description.$error }">
          {{ $t('ATTRIBUTES_MGMT.ADD.FORM.DESC.LABEL') }}
          <textarea
            v-model.trim="description"
            rows="5"
            type="text"
            :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.DESC.PLACEHOLDER')"
            @blur="$v.description.$touch"
          />
          <span v-if="$v.description.$error" class="message">
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.DESC.ERROR') }}
          </span>
        </label>

        <div v-if="isAttributeTypeList && selectedAttribute.is_kanban" class="pipeline-stages-section">
          <label class="stages-label">
            {{ $t('ATTRIBUTES_MGMT.EDIT.TYPE.LIST.LABEL') }}
          </label>
          <p class="stages-helper-text">
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.STAGES.HELPER') }}
          </p>
          <draggable
            v-model="values"
            class="stages-list"
            animation="200"
            ghost-class="stage-ghost"
            handle=".drag-handle"
            @end="onStageReorder"
          >
            <div 
              v-for="(stage, index) in values" 
              :key="index"
              class="stage-item"
            >
              <div class="drag-handle" :title="$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.DRAG_HINT')">
                <fluent-icon icon="drag" size="16" />
              </div>
              <div class="stage-number">{{ index + 1 }}</div>
              <woot-input
                v-model.trim="stage.name"
                :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.PLACEHOLDER')"
                class="stage-input"
              />
              <button 
                v-if="values.length > 1"
                type="button"
                class="remove-stage"
                :title="$t('KANBAN.CREATE_PIPELINE.FORM.STAGES.REMOVE_HINT')"
                @click.prevent="removeStage(index)"
              >
                <fluent-icon icon="dismiss" size="16" />
              </button>
            </div>
          </draggable>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            class="add-stage-btn"
            type="button"
            @click.prevent="addStage"
          >
            <fluent-icon icon="add" size="16" />
            {{ $t('KANBAN.CREATE_PIPELINE.FORM.STAGES.ADD') }}
          </woot-button>
          <label v-show="isMultiselectInvalid" class="error-message">
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.ERROR') }}
          </label>
        </div>
        <div v-if="isAttributeTypeList && !selectedAttribute.is_kanban" class="multiselect--wrap">
          <label>
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.LABEL') }}
          </label>
          <multiselect
            ref="tagInput"
            v-model="values"
            :placeholder="
              $t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.PLACEHOLDER')
            "
            label="name"
            track-by="name"
            :class="{ invalid: isMultiselectInvalid }"
            :options="options"
            :multiple="true"
            :taggable="true"
            @close="onTouch"
            @tag="addTagValue"
          />
          <label v-show="isMultiselectInvalid" class="error-message">
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.ERROR') }}
          </label>
        </div>
        <div v-if="isAttributeTypeText">
          <input
            v-model="regexEnabled"
            type="checkbox"
            @input="toggleRegexEnabled"
          />
          {{ $t('ATTRIBUTES_MGMT.ADD.FORM.ENABLE_REGEX.LABEL') }}
        </div>
        <woot-input
          v-if="isAttributeTypeText && isRegexEnabled"
          v-model="regexPattern"
          :label="$t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_PATTERN.LABEL')"
          type="text"
          :placeholder="
            $t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_PATTERN.PLACEHOLDER')
          "
        />
        <woot-input
          v-if="isAttributeTypeText && isRegexEnabled"
          v-model="regexCue"
          :label="$t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_CUE.LABEL')"
          type="text"
          :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_CUE.PLACEHOLDER')"
        />
      </div>
      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <woot-button :is-loading="isUpdating" :disabled="isButtonDisabled">
          {{ $t('ATTRIBUTES_MGMT.EDIT.UPDATE_BUTTON_TEXT') }}
        </woot-button>
        <woot-button variant="clear" type="button" @click.prevent="onClose">
          {{ $t('ATTRIBUTES_MGMT.ADD.CANCEL_BUTTON_TEXT') }}
        </woot-button>
      </div>
    </form>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, minLength } from 'vuelidate/lib/validators';
import customAttributeMixin from '../../../../mixins/customAttributeMixin';
import draggable from 'vuedraggable';
import Multiselect from 'vue-multiselect';
export default {
  components: {
    draggable,
    Multiselect,
  },
  mixins: [customAttributeMixin],
  props: {
    selectedAttribute: {
      type: Object,
      default: () => {},
    },
    isUpdating: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      displayName: '',
      description: '',
      attributeType: 6,
      regexPattern: null,
      regexCue: null,
      regexEnabled: false,
      show: true,
      values: [],
      options: [],
      isTouched: true,
    };
  },
  validations: {
    displayName: {
      required,
    },
    description: {
      required,
      minLength: minLength(1),
    },
  },
  computed: {
    ...mapGetters({
      uiFlags: 'attributes/getUIFlags',
    }),
    setAttributeListValue() {
      return this.selectedAttribute.attribute_values.map(values => ({
        name: values,
      }));
    },
    updatedAttributeListValues() {
      return this.values.map(item => item.name);
    },
    isButtonDisabled() {
      return this.$v.description.$invalid || this.isMultiselectInvalid;
    },
    isMultiselectInvalid() {
      return (
        this.isAttributeTypeList && this.isTouched && this.values.length === 0
      );
    },

    pageTitle() {
      if (this.selectedAttribute.is_kanban) {
        return `${this.$t('ATTRIBUTES_MGMT.EDIT.EDIT_PIPELINE')} - ${this.selectedAttribute.attribute_display_name}`;
      }
      return `${this.$t('ATTRIBUTES_MGMT.EDIT.TITLE')} - ${
        this.selectedAttribute.attribute_display_name
      }`;
    },

    isAttributeTypeList() {
      return this.attributeType === 6;
    },
    isAttributeTypeText() {
      return this.attributeType === 0;
    },
    isRegexEnabled() {
      return this.regexEnabled;
    },
  },
  mounted() {
    this.setFormValues();
  },
  methods: {
    onClose() {
      this.$emit('on-cancel');
    },
    addTagValue(tagValue) {
      const tag = {
        name: tagValue,
      };
      this.values.push(tag);
      this.$refs.tagInput.$el.focus();
    },
    onTouch() {
      this.isTouched = true;
    },
    addStage() {
      this.values.push({ name: '' });
    },
    removeStage(index) {
      this.values.splice(index, 1);
    },
    onStageReorder() {
      // A reatividade do Vue atualiza automaticamente os números dos estágios
      // quando o array values é reordenado pelo vuedraggable
    },
    setFormValues() {
      const regexPattern = this.selectedAttribute.regex_pattern
        ? this.getRegexp(this.selectedAttribute.regex_pattern).source
        : null;
      this.displayName = this.selectedAttribute.attribute_display_name;
      this.description = this.selectedAttribute.attribute_description;
      this.attributeType = 6; // Sempre será lista para Kanban
      this.regexPattern = regexPattern;
      this.regexCue = this.selectedAttribute.regex_cue;
      this.regexEnabled = regexPattern != null;
      this.values = this.setAttributeListValue;
    },
    async editAttributes() {
      this.$v.$touch();
      if (this.$v.$invalid) {
        return;
      }
      if (!this.regexEnabled) {
        this.regexPattern = null;
        this.regexCue = null;
      }
      try {
        await this.$store.dispatch('attributes/update', {
          id: this.selectedAttribute.id,
          attribute_description: this.description,
          attribute_display_name: this.displayName,
          attribute_values: this.updatedAttributeListValues,
          regex_pattern: this.regexPattern
            ? new RegExp(this.regexPattern).toString()
            : null,
          regex_cue: this.regexCue,
        });
        this.alertMessage = this.$t('ATTRIBUTES_MGMT.EDIT.API.SUCCESS_MESSAGE');
        this.$emit('on-close');
      } catch (error) {
        const errorMessage = error?.message;
        this.alertMessage =
          errorMessage || this.$t('ATTRIBUTES_MGMT.EDIT.API.ERROR_MESSAGE');
      } finally {
        useAlert(this.alertMessage);
      }
    },
    toggleRegexEnabled() {
      this.regexEnabled = !this.regexEnabled;
    },
  },
};
</script>
<style lang="scss" scoped>
.key-value {
  padding: 0 var(--space-small) var(--space-small) 0;
  font-family: monospace;
}
.multiselect--wrap {
  margin-bottom: var(--space-normal);
  .error-message {
    color: var(--r-400);
    font-size: var(--font-size-small);
    font-weight: var(--font-weight-normal);
  }
  .invalid {
    ::v-deep {
      .multiselect__tags {
        border: 1px solid var(--r-400);
      }
    }
  }
}

.pipeline-stages-section {
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
    @apply mt-3 inline-flex items-center gap-1;
    margin-top: var(--space-small);
    display: inline-flex;
    align-items: center;
    gap: var(--space-smaller);
  }
  
  .error-message {
    @apply text-red-500 dark:text-red-400 text-sm mt-2;
    color: var(--r-400);
    font-size: var(--font-size-small);
    font-weight: var(--font-weight-normal);
  }
}
::v-deep {
  .multiselect {
    margin-bottom: 0;
  }
  .multiselect__content-wrapper {
    display: none;
  }
  .multiselect--active .multiselect__tags {
    border-radius: var(--border-radius-normal);
  }
}
</style>
