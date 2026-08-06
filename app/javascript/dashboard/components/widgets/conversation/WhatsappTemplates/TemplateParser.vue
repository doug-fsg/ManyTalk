<template>
  <div class="w-full">
    <textarea
      v-if="renderedHeader"
      v-model="renderedHeader"
      :rows="1"
      readonly
      class="template-input header-preview"
    />
    <textarea
      v-model="processedString"
      :rows="campaignMode ? 2 : 4"
      readonly
      class="template-input"
    />
    <div v-if="bodyVariables.length" class="template__variables-container">
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.VARIABLES_LABEL') }}
      </p>
    <div
      v-for="variable in bodyVariables"
      :key="variable"
      class="template__variable-item"
    >
      <span class="variable-label">
        {{ variable }}
      </span>
      <template-variable-input
        v-if="processedParams.body"
        v-model="processedParams.body[variable]"
        :placeholder="
          $t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
            variable,
          })
        "
      />
    </div>
    </div>

    <div
      v-if="
        textHeaderVariables.length &&
        processedParams.header &&
        !requiresDynamicMediaUrl
      "
      class="template__variables-container"
    >
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_VARIABLES_LABEL') }}
      </p>
      <div
        v-for="variable in textHeaderVariables"
        :key="`header-${variable}`"
        class="template__variable-item"
      >
        <span class="variable-label">
          {{ variable }}
        </span>
        <template-variable-input
          v-model="processedParams.header[variable]"
          :placeholder="
            $t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
              variable,
            })
          "
        />
      </div>
    </div>

    <div
      v-if="requiresDynamicMediaUrl && processedParams.header"
      class="template__variables-container"
    >
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_MEDIA_LABEL') }}
      </p>
      <p class="media-hint">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_MEDIA_HINT') }}
      </p>
      <div class="template__variable-item">
        <span class="variable-label">
          {{ headerComponent.format }}
        </span>
        <woot-input
          v-model="processedParams.header.media_url"
          type="url"
          class="variable-input"
          :styles="{ marginBottom: 0 }"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.HEADER_MEDIA_URL_PLACEHOLDER')"
        />
      </div>
      <div
        v-if="headerComponent.format.toLowerCase() === 'document'"
        class="template__variable-item"
      >
        <span class="variable-label">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_MEDIA_NAME_LABEL') }}
        </span>
        <woot-input
          v-model="processedParams.header.media_name"
          type="text"
          class="variable-input"
          :styles="{ marginBottom: 0 }"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.HEADER_MEDIA_NAME_PLACEHOLDER')"
        />
      </div>
    </div>

    <div
      v-if="useEnhancedTemplateFormat && buttonFields.length"
      class="template__variables-container"
    >
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.BUTTONS_LABEL') }}
      </p>
      <div
        v-for="buttonField in buttonFields"
        :key="buttonField.index"
        class="template__variable-item"
      >
        <span class="variable-label">
          {{ buttonField.label }}
        </span>
        <template-variable-input
          v-model="processedParams.buttons[buttonField.index].parameter"
          :placeholder="buttonField.placeholder"
        />
      </div>
    </div>

    <p v-if="$v.$dirty && $v.$invalid" class="error">
      {{ $t('WHATSAPP_TEMPLATES.PARSER.FORM_ERROR_MESSAGE') }}
    </p>

    <footer v-if="!campaignMode">
      <woot-button variant="smooth" @click="$emit('resetTemplate')">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL') }}
      </woot-button>
      <woot-button type="button" :disabled="isFormInvalid" @click="sendMessage">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.SEND_MESSAGE_LABEL') }}
      </woot-button>
    </footer>
    <div v-else class="campaign-parser-footer">
      <button type="button" class="back-link" @click="$emit('resetTemplate')">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL') }}
      </button>
    </div>
  </div>
</template>

<script>
import { requiredIf } from 'vuelidate/lib/validators';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  allKeysRequired,
  buildTemplateParameters,
  COMPONENT_TYPES,
  findComponentByType,
  getTextHeaderVariables,
  hasMediaHeader,
  interpolateParamsValues,
  isWhatsAppComplete,
  renderTemplatePreview,
  replaceTemplateVariables,
  requiresDynamicMediaUrl,
  shouldUseEnhancedTemplateFormat,
} from 'dashboard/helper/templateHelper';
import {
  applySavedTemplateDefaults,
  buildTemplateDefaultsSettingsUpdate,
  getSavedTemplateDefaults,
} from 'dashboard/helper/whatsappTemplateDefaultsHelper';
import TemplateVariableInput from './TemplateVariableInput.vue';

export default {
  components: { TemplateVariableInput },
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();

    return {
      uiSettings,
      updateUISettings,
    };
  },
  props: {
    template: {
      type: Object,
      default: () => ({}),
    },
    variables: {
      type: Object,
      default: () => ({}),
    },
    campaignMode: {
      type: Boolean,
      default: false,
    },
  },
  validations: {
    processedParams: {
      requiredIfKeysPresent: requiredIf(function requiredIfKeysPresent() {
        return this.hasAnyVariables;
      }),
      allKeysRequired,
    },
  },
  data() {
    return {
      processedParams: {},
    };
  },
  computed: {
    useEnhancedTemplateFormat() {
      return shouldUseEnhancedTemplateFormat(this.template);
    },
    headerComponent() {
      return findComponentByType(this.template, COMPONENT_TYPES.HEADER);
    },
    hasMediaHeader() {
      return hasMediaHeader(this.template);
    },
    requiresDynamicMediaUrl() {
      return requiresDynamicMediaUrl(this.template);
    },
    textHeaderVariables() {
      return getTextHeaderVariables(this.template);
    },
    bodyVariables() {
      const bodyComponent = findComponentByType(
        this.template,
        COMPONENT_TYPES.BODY
      );
      if (!bodyComponent?.text) return [];

      const matchedVariables = bodyComponent.text.match(/{{([^}]+)}}/g);
      if (!matchedVariables) return [];

      return matchedVariables.map(variable =>
        variable.replace(/{{|}}/g, '')
      );
    },
    hasAnyVariables() {
      const baseParams = buildTemplateParameters(this.template);
      return Object.keys(baseParams).length > 0;
    },
    isFormInvalid() {
      return !isWhatsAppComplete(this.template, this.processedParams);
    },
    renderedHeader() {
      const header = this.headerComponent;
      if (!header?.text || header.format !== 'TEXT') return '';

      const interpolatedParams = interpolateParamsValues(
        this.processedParams,
        this.variables
      );

      return renderTemplatePreview(
        header.text,
        interpolatedParams.header || {}
      );
    },
    processedString() {
      const bodyComponent = findComponentByType(
        this.template,
        COMPONENT_TYPES.BODY
      );
      if (!bodyComponent?.text) return '';

      const interpolatedParams = interpolateParamsValues(
        this.processedParams,
        this.variables
      );

      return replaceTemplateVariables(bodyComponent.text, interpolatedParams);
    },
    buttonFields() {
      if (!this.useEnhancedTemplateFormat) return [];

      const buttonComponents =
        this.template.components?.filter(
          component => component.type === COMPONENT_TYPES.BUTTONS
        ) || [];

      const fields = [];
      buttonComponents.forEach(buttonComponent => {
        buttonComponent.buttons?.forEach((button, index) => {
          if (button.type === 'URL' && button.url?.includes('{{')) {
            fields.push({
              index,
              label: button.text || `URL ${index + 1}`,
              placeholder: button.url,
            });
          }
          if (button.type === 'COPY_CODE') {
            fields.push({
              index,
              label: this.$t('WHATSAPP_TEMPLATES.PARSER.COPY_CODE_LABEL'),
              placeholder: this.$t(
                'WHATSAPP_TEMPLATES.PARSER.COPY_CODE_PLACEHOLDER'
              ),
            });
          }
        });
      });

      return fields;
    },
  },
  created() {
    this.generateVariables();
  },
  mounted() {
    if (this.campaignMode) {
      this.emitCampaignPayload();
    }
  },
  watch: {
    template: {
      deep: true,
      handler() {
        this.generateVariables();
      },
    },
    processedParams: {
      deep: true,
      handler() {
        if (this.campaignMode) {
          this.emitCampaignPayload();
        }
      },
    },
  },
  methods: {
    buildPayload() {
      const interpolatedParams = interpolateParamsValues(
        this.processedParams,
        this.variables
      );

      const bodyComponent = findComponentByType(
        this.template,
        COMPONENT_TYPES.BODY
      );
      const messageContent = bodyComponent?.text
        ? replaceTemplateVariables(bodyComponent.text, interpolatedParams)
        : '';

      return {
        message: messageContent,
        templateParams: {
          name: this.template.name,
          category: this.template.category,
          language: this.template.language,
          namespace: this.template.namespace,
          processed_params: interpolatedParams,
        },
      };
    },
    emitCampaignPayload() {
      this.$emit('change', this.buildPayload());
    },
    sendMessage() {
      this.$v.$touch();
      if (this.$v.$invalid || this.isFormInvalid) return;

      this.persistTemplateDefaults();
      this.$emit('sendMessage', this.buildPayload());
    },
    persistTemplateDefaults() {
      const settingsUpdate = buildTemplateDefaultsSettingsUpdate(
        this.uiSettings,
        this.template,
        this.processedParams
      );

      if (!settingsUpdate) {
        return;
      }

      this.updateUISettings(settingsUpdate);
    },
    generateVariables() {
      const baseParams = buildTemplateParameters(this.template);

      const savedDefaults = getSavedTemplateDefaults(
        this.uiSettings,
        this.template
      );

      this.processedParams = applySavedTemplateDefaults(
        baseParams,
        savedDefaults
      );
    },
  },
};
</script>

<style scoped lang="scss">
.template__variables-container {
  @apply p-2.5;
}

.variables-label {
  @apply text-sm font-semibold mb-2.5;
}

.media-hint {
  @apply text-xs text-slate-500 dark:text-slate-400 mb-2.5;
}

.template__variable-item {
  @apply items-center flex mb-2.5;

  .label {
    @apply text-xs;
  }

  .variable-input {
    @apply flex-1 text-sm ml-2.5;
  }

  .variable-label {
    @apply bg-slate-75 dark:bg-slate-700 text-slate-700 dark:text-slate-100 inline-block rounded-md text-xs py-2.5 px-6;
  }
}

footer {
  @apply flex justify-end;

  button {
    @apply ml-2.5;
  }
}
.error {
  @apply bg-red-100 dark:bg-red-100 rounded-md text-red-800 dark:text-red-800 p-2.5 text-center;
}
.template-input {
  @apply bg-slate-25 dark:bg-slate-900 text-slate-700 dark:text-slate-100;
}

.header-preview {
  @apply mb-2 font-semibold;
}

.campaign-parser-footer {
  @apply mt-2;

  .back-link {
    @apply text-xs text-slate-500 dark:text-slate-400 hover:text-woot-500 underline bg-transparent border-0 p-0 cursor-pointer;
  }
}
</style>
