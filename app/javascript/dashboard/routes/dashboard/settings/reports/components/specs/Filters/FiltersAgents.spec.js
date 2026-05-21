import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReportsFiltersAgents from '../../Filters/Agents.vue';

const mockStore = createStore({
  modules: {
    agents: {
      namespaced: true,
      state: {
        agents: [],
      },
      getters: {
        getAgents: state => state.agents,
      },
      actions: {
        get: vi.fn(),
      },
    },
  },
});

const globalOpts = {
  plugins: [mockStore],
  mocks: { $t: msg => msg },
  stubs: ['multiselect'],
};

describe('ReportsFiltersAgents.vue', () => {
  it('emits "agents-filter-selection" event when handleInput is called', () => {
    const wrapper = shallowMount(ReportsFiltersAgents, { global: globalOpts });

    const selectedAgents = [
      { id: 1, name: 'Agent 1' },
      { id: 2, name: 'Agent 2' },
    ];
    wrapper.setData({ selectedOptions: selectedAgents });

    wrapper.vm.handleInput();

    expect(wrapper.emitted('agentsFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('agentsFilterSelection')[0]).toEqual([selectedAgents]);
  });

  it('dispatches the "agents/get" action when the component is mounted', () => {
    const dispatchSpy = vi.spyOn(mockStore, 'dispatch');

    shallowMount(ReportsFiltersAgents, { global: globalOpts });

    expect(dispatchSpy).toHaveBeenCalledWith('agents/get');
  });
});
