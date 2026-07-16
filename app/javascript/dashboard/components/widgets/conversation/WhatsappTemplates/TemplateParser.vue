<template>
  <div class="w-full">
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
          v-if="enhancedTemplatesEnabled"
          v-model="processedParams.body[variable]"
          :placeholder="
            $t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
              variable,
            })
          "
        />
        <template-variable-input
          v-else
          v-model="processedParams[variable]"
          :placeholder="
            $t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
              variable,
            })
          "
        />
      </div>
    </div>

    <div v-if="enhancedTemplatesEnabled && hasMediaHeader" class="template__variables-container">
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_MEDIA_LABEL') }}
      </p>
      <div class="template__variable-item">
        <span class="variable-label">
          {{ headerComponent.format }}
        </span>
        <woot-input
          v-model="processedParams.header.media_url"
          type="text"
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
      v-if="enhancedTemplatesEnabled && buttonFields.length"
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
      <woot-button type="button" @click="sendMessage">
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
import { mapGetters } from 'vuex';
import { requiredIf } from 'vuelidate/lib/validators';
import accountMixin from 'dashboard/mixins/account';
import {
  allKeysRequired,
  buildLegacyTemplateParameters,
  buildTemplateParameters,
  findComponentByType,
  hasMediaHeader,
  interpolateParamsValues,
  replaceTemplateVariables,
  COMPONENT_TYPES,
} from 'dashboard/helper/templateHelper';
import TemplateVariableInput from './TemplateVariableInput.vue';

export default {
  components: { TemplateVariableInput },
  mixins: [accountMixin],
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
    ...mapGetters({
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    enhancedTemplatesEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        'whatsapp_enhanced_templates'
      );
    },
    headerComponent() {
      return findComponentByType(this.template, COMPONENT_TYPES.HEADER);
    },
    hasMediaHeader() {
      return hasMediaHeader(this.template);
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
      return (
        this.bodyVariables.length > 0 ||
        (this.enhancedTemplatesEnabled && this.hasMediaHeader) ||
        this.buttonFields.length > 0
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
      if (!this.enhancedTemplatesEnabled) return [];

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
  mounted() {
    this.generateVariables();
    if (this.campaignMode) {
      this.emitCampaignPayload();
    }
  },
  watch: {
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
      if (this.$v.$invalid) return;

      this.$emit('sendMessage', this.buildPayload());
    },
    generateVariables() {
      if (this.enhancedTemplatesEnabled) {
        this.processedParams = buildTemplateParameters(
          this.template,
          true
        );
        return;
      }

      this.processedParams = buildLegacyTemplateParameters(this.template);
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

.campaign-parser-footer {
  @apply mt-2;

  .back-link {
    @apply text-xs text-slate-500 dark:text-slate-400 hover:text-woot-500 underline bg-transparent border-0 p-0 cursor-pointer;
  }
}
</style>
