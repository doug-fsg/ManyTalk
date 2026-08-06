import { createLocalVue, mount } from '@vue/test-utils';
import VueI18n from 'vue-i18n';
import Button from 'dashboard/components/buttons/Button.vue';
import i18n from 'dashboard/i18n';
import ReguaPanelStartForm from '../ReguaPanelStartForm.vue';

const localVue = createLocalVue();
localVue.use(VueI18n);
localVue.component('woot-button', Button);

const i18nConfig = new VueI18n({ locale: 'pt_BR', messages: i18n });

describe('ReguaPanelStartForm', () => {
  it('shows only the start button when workflows are available', () => {
    const wrapper = mount(ReguaPanelStartForm, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        workflows: [{ id: 1, name: 'Follow-up' }],
        isLoading: false,
        isStarting: false,
      },
    });

    const buttons = wrapper.findAll('button');
    expect(buttons.length).toBe(1);
    expect(buttons.at(0).text()).toContain('Iniciar fluxo');
    expect(wrapper.text()).not.toContain('Concluído');
  });

  it('disables start until a workflow is selected', async () => {
    const wrapper = mount(ReguaPanelStartForm, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        workflows: [{ id: 1, name: 'Follow-up' }],
      },
    });

    expect(wrapper.find('button').attributes('disabled')).toBe('disabled');

    await wrapper.find('select').setValue('1');
    expect(wrapper.find('button').attributes('disabled')).toBeUndefined();
  });

  it('emits start with selected workflow id', async () => {
    const wrapper = mount(ReguaPanelStartForm, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        workflows: [{ id: 42, name: 'Follow-up' }],
      },
    });

    await wrapper.find('select').setValue('42');
    await wrapper.find('button').trigger('click');

    expect(wrapper.emitted('start')).toEqual([[42]]);
  });

  it('shows empty-state message when no active workflows exist', () => {
    const wrapper = mount(ReguaPanelStartForm, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        workflows: [],
      },
    });

    expect(wrapper.text()).toContain('Nenhum fluxo ativo disponível');
    expect(wrapper.find('select').exists()).toBe(false);
  });
});
