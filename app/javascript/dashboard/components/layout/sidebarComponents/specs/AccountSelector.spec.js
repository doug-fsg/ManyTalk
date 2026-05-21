import AccountSelector from '../AccountSelector.vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import i18n from 'dashboard/i18n';
import WootModal from 'dashboard/components/Modal.vue';
import WootModalHeader from 'dashboard/components/ModalHeader.vue';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

describe('accountSelctor', () => {
  let accountSelector = null;
  const currentUser = {
    accounts: [
      { id: 1, name: 'Chatwoot', role: 'administrator' },
      { id: 2, name: 'GitX', role: 'agent' },
    ],
  };

  let actions = null;
  let modules = null;

  beforeEach(() => {
    actions = {};
    modules = {
      auth: {
        getters: {
          getCurrentAccountId: () => 1,
          getCurrentUser: () => currentUser,
        },
      },
      globalConfig: {
        getters: {
          'globalConfig/get': () => ({ createNewAccountFromDashboard: false }),
        },
      },
    };

    const store = createStore({ actions, modules });
    accountSelector = mount(AccountSelector, {
      props: { showAccountModal: true },
      global: {
        plugins: [store, i18nInstance],
        components: {
          'woot-modal': WootModal,
          'woot-modal-header': WootModalHeader,
          'fluent-icon': FluentIcon,
        },
        stubs: { WootButton: { template: '<button />' } },
      },
    });
  });

  it('title and sub title exist', () => {
    const headerComponent = accountSelector.findComponent(WootModalHeader);
    const title = headerComponent.findComponent({ ref: 'modalHeaderTitle' });
    expect(title.text()).toBe('Switch Account');
    const content = headerComponent.findComponent({ ref: 'modalHeaderContent' });
    expect(content.text()).toBe('Select an account from the following list');
  });

  it('first account item is checked', () => {
    const selectedAccountCheckmark = accountSelector.find('#account-1 > button > svg');
    expect(selectedAccountCheckmark.exists()).toBe(true);

    const otherAccountCheckmark = accountSelector.find('#account-2 > button > svg');
    expect(otherAccountCheckmark.exists()).toBe(true);
  });
});
