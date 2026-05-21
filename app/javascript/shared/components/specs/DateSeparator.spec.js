import DateSeparator from '../DateSeparator.vue';
import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import darkModeMixin from 'widget/mixins/darkModeMixin.js';
import i18n from 'dashboard/i18n';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

describe('dateSeparator', () => {
  let store = null;
  let dateSeparator = null;

  beforeEach(() => {
    store = createStore({
      modules: {
        auth: {
          getters: {
            'appConfig/darkMode': () => 'light',
          },
        },
      },
    });

    dateSeparator = shallowMount(DateSeparator, {
      props: { date: 'Nov 18, 2019' },
      global: {
        plugins: [store, i18nInstance],
        mocks: { $t: msg => msg },
        mixins: [darkModeMixin],
      },
    });
  });

  it('date separator snapshot', () => {
    expect(dateSeparator.vm).toBeTruthy();
    expect(dateSeparator.element).toMatchSnapshot();
  });
});
