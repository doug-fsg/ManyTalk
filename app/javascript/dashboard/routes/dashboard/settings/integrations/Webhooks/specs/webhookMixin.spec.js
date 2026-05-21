import { mount } from '@vue/test-utils';
import webhookMixin from '../webhookMixin';

describe('webhookMixin', () => {
  describe('#getEventLabel', () => {
    it('returns correct i18n translation:', () => {
      const Component = {
        render() {},
        title: 'WebhookComponent',
        mixins: [webhookMixin],
        methods: {
          $t(text) {
            return text;
          },
        },
      };
      const wrapper = mount(Component);
      expect(wrapper.vm.getEventLabel('message_created')).toEqual(
        `INTEGRATION_SETTINGS.WEBHOOK.FORM.SUBSCRIPTIONS.EVENTS.MESSAGE_CREATED`
      );
    });
  });
});
