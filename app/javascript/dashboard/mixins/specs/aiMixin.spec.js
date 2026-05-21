import { shallowMount } from '@vue/test-utils';
import aiMixin from '../aiMixin';
import { createStore } from 'vuex';
import OpenAPI from '../../api/integrations/openapi';
import { LocalStorage } from '../../../shared/helpers/localStorage';

vi.mock('../../api/integrations/openapi');
vi.mock('../../../shared/helpers/localStorage');

describe('aiMixin', () => {
  let wrapper;
  let getters;
  let emptyGetters;
  let component;
  let actions;

  beforeEach(() => {
    OpenAPI.processEvent = vi.fn();
    LocalStorage.set = vi.fn();
    LocalStorage.get = vi.fn();

    actions = {
      ['integrations/get']: vi.fn(),
    };

    getters = {
      ['integrations/getAppIntegrations']: () => [
        {
          id: 'openai',
          hooks: [{ id: 'hook1' }],
        },
      ],
    };

    component = {
      render() {},
      title: 'TestComponent',
      mixins: [aiMixin],
    };

    wrapper = shallowMount(component, {
      global: {
        plugins: [
          createStore({
            getters: getters,
            actions,
          }),
        ],
      },
    });

    emptyGetters = {
      ['integrations/getAppIntegrations']: () => [],
    };
  });

  it('fetches integrations if required', async () => {
    wrapper = shallowMount(component, {
      global: {
        plugins: [
          createStore({
            getters: emptyGetters,
            actions,
          }),
        ],
      },
    });

    const dispatchSpy = vi.spyOn(wrapper.vm.$store, 'dispatch');
    await wrapper.vm.fetchIntegrationsIfRequired();
    expect(dispatchSpy).toHaveBeenCalledWith('integrations/get');
  });

  it('does not fetch integrations', async () => {
    const dispatchSpy = vi.spyOn(wrapper.vm.$store, 'dispatch');
    await wrapper.vm.fetchIntegrationsIfRequired();
    expect(dispatchSpy).not.toHaveBeenCalledWith('integrations/get');
    expect(wrapper.vm.isAIIntegrationEnabled).toBeTruthy();
  });

  it('fetches label suggestions', async () => {
    const processEventSpy = vi.spyOn(OpenAPI, 'processEvent');
    await wrapper.vm.fetchLabelSuggestions({
      conversationId: '123',
    });

    expect(processEventSpy).toHaveBeenCalledWith({
      type: 'label_suggestion',
      hookId: 'hook1',
      conversationId: '123',
    });
  });

  it('cleans labels', () => {
    const labels = 'label1, label2, label1';
    expect(wrapper.vm.cleanLabels(labels)).toEqual(['label1', 'label2']);
  });
});
