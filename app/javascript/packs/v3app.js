import { createApp, h, configureCompat } from 'vue';
import { createI18n } from 'vue-i18n';
import Vuelidate from 'vuelidate';
import i18n from 'dashboard/i18n';
import * as Sentry from '@sentry/vue';
import { Integrations } from '@sentry/tracing';
import {
  initializeAnalyticsEvents,
  initializeChatwootEvents,
} from 'dashboard/helper/scriptHelpers';
import AnalyticsPlugin from 'dashboard/helper/AnalyticsHelper/plugin';
import App from '../v3/App.vue';
import router, { initalizeRouter } from '../v3/views/index';
import store from '../v3/store';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon';
import { emitter } from '../shared/helpers/mitt';
import { compatConfigV3App } from 'shared/compatConfig';

configureCompat(compatConfigV3App);

const i18nInstance = createI18n({
  legacy: true,
  locale: 'en',
  messages: i18n,
});

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
  app.use(Vuelidate);
  app.use(AnalyticsPlugin);
  app.component('fluent-icon', FluentIcon);
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

  app.mount('#app');
};
