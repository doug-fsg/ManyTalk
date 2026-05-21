import NotificationBell from '../NotificationBell.vue';
import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import i18n from 'dashboard/i18n';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

const $route = { name: 'notifications_index' };

describe('notificationBell', () => {
  const accountId = 1;
  const notificationMetadata = { unreadCount: 19 };
  let store = null;

  beforeEach(() => {
    store = createStore({
      modules: {
        auth: {
          getters: {
            getCurrentAccountId: () => accountId,
          },
        },
        notifications: {
          getters: {
            'notifications/getMeta': () => notificationMetadata,
          },
        },
      },
    });
  });

  const mountOpts = () => ({
    global: {
      plugins: [store, i18nInstance],
      components: { 'fluent-icon': FluentIcon },
      mocks: { $route },
    },
  });

  it('it should return unread count 19 ', () => {
    const wrapper = shallowMount(NotificationBell, mountOpts());
    expect(wrapper.vm.unreadCount).toBe('19');
  });

  it('it should return unread count 99+ ', async () => {
    notificationMetadata.unreadCount = 100;
    const wrapper = shallowMount(NotificationBell, mountOpts());
    expect(wrapper.vm.unreadCount).toBe('99+');
  });

  it('isNotificationPanelActive', async () => {
    const notificationBell = shallowMount(NotificationBell, mountOpts());
    expect(notificationBell.vm.isNotificationPanelActive).toBe(true);
  });
});
