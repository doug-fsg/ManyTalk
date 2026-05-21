import { createApp, h, configureCompat } from 'vue';
import Vuelidate from 'vuelidate';
import { createI18n } from 'vue-i18n';
import VueDOMPurifyHTML from 'vue-dompurify-html';
import VueFormulate from '@braid/vue-formulate';
import store from '../widget/store';
import App from '../widget/App.vue';
import ActionCableConnector from '../widget/helpers/actionCable';
import i18n from '../widget/i18n';
import {
  startsWithPlus,
  isPhoneNumberValidWithDialCode,
} from 'shared/helpers/Validators';
import router from '../widget/router';
import onClickAwayDirective from 'shared/directives/onClickOutside';
import { emitter } from 'shared/helpers/mitt';
import { domPurifyConfig } from '../shared/helpers/HTMLSanitizer';
import { compatConfig } from 'shared/compatConfig';
const PhoneInput = () => import('../widget/components/Form/PhoneInput');

configureCompat(compatConfig);

const i18nInstance = createI18n({
  legacy: true,
  locale: 'en',
  messages: i18n,
});

window.onload = () => {
  const app = createApp({
    render: () => h(App),
  });

  app.use(router);
  app.use(store);
  app.use(i18nInstance);
  app.use(Vuelidate);
  app.use(VueDOMPurifyHTML, domPurifyConfig);
  app.directive('on-clickaway', onClickAwayDirective);
  app.use(VueFormulate, {
    library: {
      phoneInput: {
        classification: 'number',
        component: PhoneInput,
        slotProps: {
          component: ['placeholder', 'hasErrorInPhoneInput'],
        },
      },
    },
    rules: {
      startsWithPlus: ({ value }) => startsWithPlus(value),
      isValidPhoneNumber: ({ value }) => isPhoneNumberValidWithDialCode(value),
    },
    classes: {
      outer: 'mb-2 wrapper',
      error: 'text-red-400 mt-2 text-xs leading-3 font-medium',
    },
  });
  app.config.globalProperties.$emitter = emitter;

  window.WOOT_WIDGET = app.mount('#app');

  window.actionCable = new ActionCableConnector(
    window.WOOT_WIDGET,
    window.chatwootPubsubToken
  );
};
