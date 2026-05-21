import { createApp, h, configureCompat } from 'vue';
import { createI18n } from 'vue-i18n';
import axios from 'axios';
import hljs from 'highlight.js';
import Multiselect from 'vue-multiselect';
import VueFormulate from '@braid/vue-formulate';
import WootSwitch from 'components/ui/Switch';
import WootWizard from 'components/ui/Wizard';
import { sync } from 'shared/helpers/vuexRouterSync';
import Vuelidate from 'vuelidate';
import VTooltip from 'v-tooltip';
import WootUiKit from '../dashboard/components';
import App from '../dashboard/App';
import i18n from '../dashboard/i18n';
import createAxios from '../dashboard/helper/APIHelper';
import { emitter } from '../shared/helpers/mitt';

import commonHelpers, { isJSONValid } from '../dashboard/helper/commons';
import router, { initalizeRouter } from '../dashboard/routes';
import store from '../dashboard/store';
import constants from 'dashboard/constants/globals';
import * as Sentry from '@sentry/vue';
import 'vue-easytable/libs/theme-default/index.css';
import { Integrations } from '@sentry/tracing';
import {
  initializeAnalyticsEvents,
  initializeChatwootEvents,
} from '../dashboard/helper/scriptHelpers';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon';
import VueDOMPurifyHTML from 'vue-dompurify-html';
import { domPurifyConfig } from '../shared/helpers/HTMLSanitizer';
import AnalyticsPlugin from '../dashboard/helper/AnalyticsHelper/plugin';
import resizeDirective from '../dashboard/helper/directives/resize.js';
import onClickAwayDirective from 'shared/directives/onClickOutside';
import { compatConfig } from 'shared/compatConfig';

configureCompat(compatConfig);

const i18nInstance = createI18n({
  legacy: true,
  locale: 'en',
  messages: i18n,
});

sync(store, router);
commonHelpers();

window.WootConstants = constants;
window.axios = createAxios(axios);

initializeChatwootEvents();
initializeAnalyticsEvents();
initalizeRouter();

window.onload = () => {
  const app = createApp({
    render: () => h(App),
  });

  app.use(router);
  app.use(store);
  app.use(i18nInstance);
  app.use(VueDOMPurifyHTML, domPurifyConfig);
  app.use(WootUiKit);
  app.use(Vuelidate);
  app.use(VueFormulate, {
    rules: {
      JSON: ({ value }) => isJSONValid(value),
    },
  });
  app.use(VTooltip, {
    defaultHtml: false,
  });
  app.use(hljs.vuePlugin);
  app.use(AnalyticsPlugin);

  app.component('multiselect', Multiselect);
  app.component('woot-switch', WootSwitch);
  app.component('woot-wizard', WootWizard);
  app.component('fluent-icon', FluentIcon);

  app.directive('resize', resizeDirective);
  app.directive('on-clickaway', onClickAwayDirective);

  app.config.globalProperties.$emitter = emitter;

  if (window.errorLoggingConfig) {
    Sentry.init({
      app,
      dsn: window.errorLoggingConfig,
      denyUrls: [
        /^chrome:\/\//i,
        /chrome-extension:/i,
        /extensions\//i,
        /file:\/\//i,
        /safari-web-extension:/i,
        /safari-extension:/i,
      ],
      integrations: [new Integrations.BrowserTracing()],
      ignoreErrors: [
        'ResizeObserver loop completed with undelivered notifications',
      ],
    });
  }

  window.WOOT = app.mount('#app');
};

window.addEventListener('load', () => {
  window.playAudioAlert = () => {};
});
