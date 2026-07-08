import { useAlert } from 'dashboard/composables';
import {
  buildWhatsAppTemplatesUrl,
  getInboxWabaId,
} from 'dashboard/constants/whatsappTemplateGuide';

export default {
  props: {
    inboxId: {
      type: Number,
      required: true,
    },
  },
  computed: {
    inbox() {
      return this.$store.getters['inboxes/getInboxes'].find(
        record => record.id === Number(this.inboxId)
      );
    },
    wabaId() {
      return getInboxWabaId(this.inbox);
    },
    metaTemplatesUrl() {
      return buildWhatsAppTemplatesUrl(this.wabaId);
    },
    isSyncing() {
      return this.$store.getters['inboxes/getUIFlags'].isSyncingTemplates;
    },
    approvedTemplatesCount() {
      return this.$store.getters['inboxes/getWhatsAppTemplates'](
        this.inboxId
      ).filter(template => template.status?.toLowerCase() === 'approved').length;
    },
    settingsTemplatesUrl() {
      return `/app/accounts/${this.$store.getters.getCurrentAccountId}/settings/inboxes/${this.inboxId}?tab=whatsapp_templates`;
    },
  },
  methods: {
    async syncWhatsAppTemplates() {
      try {
        await this.$store.dispatch(
          'inboxes/syncWhatsAppTemplates',
          this.inboxId
        );
        useAlert(this.$t('WHATSAPP_TEMPLATES.GUIDE.SYNC_SUCCESS'));
        this.$emit('synced');
      } catch {
        useAlert(this.$t('WHATSAPP_TEMPLATES.GUIDE.SYNC_ERROR'));
      }
    },
  },
};
