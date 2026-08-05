<script>
import SettingsSection from '../../../../../components/SettingsSection.vue';
import whatsappTemplateGuideMixin from 'dashboard/mixins/whatsappTemplateGuideMixin';

export default {
  components: {
    SettingsSection,
  },
  mixins: [whatsappTemplateGuideMixin],
};
</script>

<template>
  <div>
    <SettingsSection
      :title="$t('WHATSAPP_TEMPLATES.GUIDE.TAB_CREATE_TITLE')"
      :sub-title="$t('WHATSAPP_TEMPLATES.GUIDE.TAB_CREATE_SUBTITLE')"
    >
      <a
        :href="metaTemplatesUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="template-link"
      >
        <woot-button>
          {{ $t('WHATSAPP_TEMPLATES.GUIDE.CREATE_TEMPLATES') }}
        </woot-button>
      </a>
    </SettingsSection>

    <SettingsSection
      :title="$t('WHATSAPP_TEMPLATES.GUIDE.TAB_SYNC_TITLE')"
      :sub-title="$t('WHATSAPP_TEMPLATES.GUIDE.TAB_SYNC_SUBTITLE')"
    >
      <p class="template-count font-semibold">
        {{
          $t('WHATSAPP_TEMPLATES.GUIDE.TEMPLATES_COUNT', {
            count: approvedTemplatesCount,
          })
        }}
      </p>
      <p v-if="pendingTemplatesCount > 0" class="template-count">
        {{
          $t('WHATSAPP_TEMPLATES.GUIDE.PENDING_TEMPLATES_COUNT', {
            count: pendingTemplatesCount,
          })
        }}
      </p>
      <woot-button
        variant="smooth"
        :is-loading="isSyncing"
        :disabled="isSyncing"
        @click="syncWhatsAppTemplates"
      >
        {{ $t('WHATSAPP_TEMPLATES.GUIDE.SYNC_BUTTON') }}
      </woot-button>
    </SettingsSection>
  </div>
</template>

<style scoped lang="scss">
.template-link {
  @apply inline-block no-underline;
}

.template-count {
  @apply text-sm text-slate-700 dark:text-slate-200 mb-3;
}
</style>
