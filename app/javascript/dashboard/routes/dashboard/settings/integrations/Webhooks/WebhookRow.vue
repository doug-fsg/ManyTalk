<script>
import webhookMixin from './webhookMixin';
import ShowMore from 'dashboard/components/widgets/ShowMore.vue';

export default {
  components: { ShowMore },
  mixins: [webhookMixin],
  props: {
    webhook: {
      type: Object,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
  },
  computed: {
    subscribedEvents() {
      const { subscriptions } = this.webhook;
      return subscriptions.map(event => this.getEventLabel(event)).join(', ');
    },
  },
};
</script>

<template>
  <tr>
    <td class="min-w-0">
      <div class="font-medium break-all text-slate-700 dark:text-slate-100">
        {{ webhook.url }}
      </div>
      <span class="text-xs text-slate-500 dark:text-slate-400">
        <span class="font-medium">
          {{ $t('INTEGRATION_SETTINGS.WEBHOOK.SUBSCRIBED_EVENTS') }}:
        </span>
        <ShowMore :text="subscribedEvents" :limit="60" />
      </span>
    </td>
    <td class="w-24 text-right align-top whitespace-nowrap">
      <div class="button-wrapper justify-end min-w-0">
        <woot-button
          v-tooltip.top="$t('INTEGRATION_SETTINGS.WEBHOOK.EDIT.BUTTON_TEXT')"
          variant="smooth"
          size="tiny"
          color-scheme="secondary"
          icon="edit"
          @click="$emit('edit', webhook)"
        />
        <woot-button
          v-tooltip.top="$t('INTEGRATION_SETTINGS.WEBHOOK.DELETE.BUTTON_TEXT')"
          variant="smooth"
          color-scheme="alert"
          size="tiny"
          icon="dismiss-circle"
          @click="$emit('delete', webhook, index)"
        />
      </div>
    </td>
  </tr>
</template>
