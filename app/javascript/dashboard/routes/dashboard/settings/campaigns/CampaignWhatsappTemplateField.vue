<template>
  <div v-if="inboxId" class="campaign-wa-template">
    <p class="field-label">
      {{ $t('CAMPAIGN.ADD.FORM.WHATSAPP_TEMPLATE.LABEL') }}
    </p>

    <templates-picker
      v-if="!selectedTemplate"
      compact
      :inbox-id="inboxId"
      @onSelect="onSelectTemplate"
    />
    <template-parser
      v-else
      campaign-mode
      :template="selectedTemplate"
      :variables="variables"
      @resetTemplate="resetTemplate"
      @change="onTemplateChange"
    />

    <span v-if="showError && !hasTemplate" class="message">
      {{ $t('CAMPAIGN.ADD.FORM.WHATSAPP_TEMPLATE.REQUIRED') }}
    </span>
  </div>
</template>

<script>
import TemplatesPicker from 'dashboard/components/widgets/conversation/WhatsappTemplates/TemplatesPicker.vue';
import TemplateParser from 'dashboard/components/widgets/conversation/WhatsappTemplates/TemplateParser.vue';

export default {
  components: {
    TemplatesPicker,
    TemplateParser,
  },
  props: {
    inboxId: {
      type: Number,
      default: null,
    },
    value: {
      type: Object,
      default: null,
    },
    variables: {
      type: Object,
      default: () => ({}),
    },
    showError: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedTemplate: null,
      localParams: null,
    };
  },
  computed: {
    hasTemplate() {
      return !!this.localParams?.templateParams;
    },
  },
  watch: {
    value: {
      immediate: true,
      handler(newValue) {
        if (!newValue?.templateParams) {
          this.localParams = null;
          return;
        }
        this.localParams = newValue;
        if (!this.selectedTemplate && newValue.templateParams?.name) {
          this.selectedTemplate = this.findTemplateByName(newValue.templateParams.name);
        }
      },
    },
    inboxId() {
      this.resetTemplate();
    },
  },
  methods: {
    findTemplateByName(name) {
      const templates = this.$store.getters[
        'inboxes/getFilteredWhatsAppTemplates'
      ](this.inboxId);
      return templates.find(template => template.name === name) || null;
    },
    onSelectTemplate(template) {
      this.selectedTemplate = template;
    },
    resetTemplate() {
      this.selectedTemplate = null;
      this.localParams = null;
      this.$emit('input', null);
    },
    onTemplateChange(payload) {
      this.localParams = payload;
      this.$emit('input', payload);
    },
  },
};
</script>

<style lang="scss" scoped>
.campaign-wa-template {
  @apply mb-4;
}

.field-label {
  @apply text-sm font-medium text-slate-800 dark:text-slate-100 mb-2;
}
</style>
