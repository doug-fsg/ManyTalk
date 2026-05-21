import { shallowMount } from '@vue/test-utils';
import accountMixin from '../account';
import { createStore } from 'vuex';

describe('accountMixin', () => {
  let getters;
  let store;

  beforeEach(() => {
    getters = {
      getCurrentAccountId: () => 1,
    };

    store = createStore({ getters });
  });

  it('set accountId properly', () => {
    const Component = {
      render() {},
      title: 'TestComponent',
      mixins: [accountMixin],
    };
    const wrapper = shallowMount(Component, {
      global: { plugins: [store] },
    });
    expect(wrapper.vm.accountId).toBe(1);
  });

  it('returns current url', () => {
    const Component = {
      render() {},
      title: 'TestComponent',
      mixins: [accountMixin],
    };

    const wrapper = shallowMount(Component, {
      global: { plugins: [store] },
    });
    expect(wrapper.vm.addAccountScoping('settings/inboxes/new')).toBe(
      '/app/accounts/1/settings/inboxes/new'
    );
  });
});
