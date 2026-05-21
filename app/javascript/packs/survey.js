import { createApp, h, configureCompat } from 'vue';
import Vuelidate from 'vuelidate';
import { createI18n } from 'vue-i18n';
import App from '../survey/App.vue';
import i18n from '../survey/i18n';
import store from '../survey/store';
import { emitter } from 'shared/helpers/mitt';
import { compatConfig } from 'shared/compatConfig';

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

  app.use(i18nInstance);
  app.use(Vuelidate);
  app.use(store);
  app.config.globalProperties.$emitter = emitter;

  window.WOOT_SURVEY = app.mount('#app');
};
