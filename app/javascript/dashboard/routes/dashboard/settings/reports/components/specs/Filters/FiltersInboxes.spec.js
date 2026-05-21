import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReportsFiltersInboxes from '../../Filters/Inboxes.vue';

const globalOpts = {
  mocks: { $t: msg => msg },
  stubs: ['multiselect'],
};

describe('ReportsFiltersInboxes.vue', () => {
  let store;
  let inboxesModule;

  beforeEach(() => {
    inboxesModule = {
      namespaced: true,
      getters: {
        getInboxes: () => () => [
          { id: 1, name: 'Inbox 1' },
          { id: 2, name: 'Inbox 2' },
        ],
      },
      actions: {
        get: vi.fn(),
      },
    };

    store = createStore({ modules: { inboxes: inboxesModule } });
  });

  it('dispatches "inboxes/get" action when component is mounted', () => {
    shallowMount(ReportsFiltersInboxes, {
      global: { ...globalOpts, plugins: [store] },
    });
    expect(inboxesModule.actions.get).toHaveBeenCalled();
  });

  it('emits "inbox-filter-selection" event when handleInput is called', () => {
    const wrapper = shallowMount(ReportsFiltersInboxes, {
      global: { ...globalOpts, plugins: [store] },
    });

    const selectedInbox = { id: 1, name: 'Inbox 1' };
    wrapper.setData({ selectedOption: selectedInbox });

    wrapper.vm.handleInput();

    expect(wrapper.emitted('inboxFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('inboxFilterSelection')[0]).toEqual([selectedInbox]);
  });
});
