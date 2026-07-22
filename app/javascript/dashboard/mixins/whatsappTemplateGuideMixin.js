import { useAlert } from 'dashboard/composables';
import {
  buildWhatsAppTemplatesUrl,
  getInboxWabaId,
} from 'dashboard/constants/whatsappTemplateGuide';

const TEMPLATE_SYNC_STALE_MS = 15 * 60 * 1000;

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
    shouldSyncTemplates() {
      if (!this.inbox || this.inbox.channel_type !== 'Channel::Whatsapp') {
        return false;
      }

      const lastUpdated = this.inbox.message_templates_last_updated;
      if (!lastUpdated) {
        return true;
      }

      return Date.now() - new Date(lastUpdated).getTime() > TEMPLATE_SYNC_STALE_MS;
    },
    async maybeSyncWhatsAppTemplates({ silent = true } = {}) {
      if (!this.inboxId || !this.shouldSyncTemplates() || this.isSyncing) {
        return;
      }

      try {
        await this.$store.dispatch(
          'inboxes/syncWhatsAppTemplates',
          this.inboxId
        );
        if (!silent) {
          useAlert(this.$t('WHATSAPP_TEMPLATES.GUIDE.SYNC_SUCCESS'));
        }
        this.$emit('synced');
      } catch {
        if (!silent) {
          useAlert(this.$t('WHATSAPP_TEMPLATES.GUIDE.SYNC_ERROR'));
        }
      }
    },
    async syncWhatsAppTemplates() {
      if (!this.inboxId || this.isSyncing) {
        return;
      }

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
