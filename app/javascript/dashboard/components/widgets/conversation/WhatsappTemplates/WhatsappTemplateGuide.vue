<template>
  <div class="template-guide-compact">
    <p class="template-guide-compact__text">
      {{ $t('WHATSAPP_TEMPLATES.GUIDE.PICKER_EMPTY') }}
    </p>
    <div class="template-guide-compact__actions">
      <router-link :to="settingsTemplatesUrl" class="template-guide-compact__link">
        {{ $t('WHATSAPP_TEMPLATES.GUIDE.PICKER_SETTINGS_LINK') }}
      </router-link>
      <woot-button
        variant="smooth"
        size="small"
        :is-loading="isSyncing"
        :disabled="isSyncing"
        @click="syncWhatsAppTemplates"
      >
        {{ $t('WHATSAPP_TEMPLATES.GUIDE.SYNC_BUTTON') }}
      </woot-button>
    </div>
  </div>
</template>

<script>
import whatsappTemplateGuideMixin from 'dashboard/mixins/whatsappTemplateGuideMixin';

export default {
  mixins: [whatsappTemplateGuideMixin],
};
</script>

<style scoped lang="scss">
.template-guide-compact {
  @apply py-2 text-center;

  &__text {
    @apply text-sm text-slate-600 dark:text-slate-300 mb-3;
  }

  &__actions {
    @apply flex flex-col items-center gap-2;
  }

  &__link {
    @apply text-sm text-woot-500 hover:underline;
  }
}
</style>
