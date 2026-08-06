import { createLocalVue, mount } from '@vue/test-utils';
import VueI18n from 'vue-i18n';
import VTooltip from 'v-tooltip';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import i18n from 'dashboard/i18n';
import ReguaTimeline from '../ReguaTimeline.vue';

const localVue = createLocalVue();
localVue.use(VueI18n);
localVue.use(VTooltip);
localVue.component('fluent-icon', FluentIcon);

const i18nConfig = new VueI18n({ locale: 'pt_BR', messages: i18n });

describe('ReguaTimeline', () => {
  it('shows info button only for action steps with details', () => {
    const wrapper = mount(ReguaTimeline, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        timeline: [
          {
            node_id: 'wait_1',
            label: 'Espera · 2 hora(s)',
            type: 'wait',
            status: 'running',
          },
          {
            node_id: 'action_1',
            label: 'Enviar uma mensagem',
            type: 'action',
            status: 'completed',
            action_details: ['Enviar uma mensagem: Olá'],
          },
        ],
        currentNodeId: 'wait_1',
      },
    });

    const infoButtons = wrapper.findAll('button');
    expect(infoButtons.length).toBe(1);
    expect(infoButtons.at(0).attributes('aria-label')).toBe(
      'O que esta ação faz'
    );
  });

  it('marks current step label as active', () => {
    const wrapper = mount(ReguaTimeline, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        timeline: [
          {
            node_id: 'wait_1',
            label: 'Espera · 2 hora(s)',
            type: 'wait',
            status: 'running',
          },
        ],
        currentNodeId: 'wait_1',
      },
    });

    expect(wrapper.text()).toContain('Agora');
    expect(wrapper.find('.font-medium.text-woot-500').exists()).toBe(true);
  });

  it('shows error message for failed steps', () => {
    const wrapper = mount(ReguaTimeline, {
      localVue,
      i18n: i18nConfig,
      propsData: {
        timeline: [
          {
            node_id: 'action_1',
            label: 'Enviar uma mensagem',
            type: 'action',
            status: 'failed',
            error_message: 'Falha ao enviar',
          },
        ],
      },
    });

    expect(wrapper.text()).toContain('Falha ao enviar');
    expect(wrapper.text()).toContain('Falhou');
  });
});
