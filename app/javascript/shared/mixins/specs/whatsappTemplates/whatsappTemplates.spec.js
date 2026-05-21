import TemplateParser from '../../../../dashboard/components/widgets/conversation/WhatsappTemplates/TemplateParser.vue';
import { shallowMount } from '@vue/test-utils';
import { templates } from './fixtures';
import { createI18n } from 'vue-i18n';
import Vuelidate from 'vuelidate';
import i18n from 'dashboard/i18n';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

const globalOpts = {
  plugins: [i18nInstance, Vuelidate],
  stubs: {
    WootButton: { template: '<button />' },
    WootInput: { template: '<input />' },
  },
};

describe('#WhatsAppTemplates', () => {
  it('returns all variables from a template string', () => {
    const wrapper = shallowMount(TemplateParser, {
      props: { template: templates[0] },
      global: globalOpts,
    });
    expect(wrapper.vm.variables).toEqual(['{{1}}', '{{2}}', '{{3}}']);
  });

  it('returns no variables from a template string if it does not contain variables', () => {
    const wrapper = shallowMount(TemplateParser, {
      props: { template: templates[12] },
      global: globalOpts,
    });
    expect(wrapper.vm.variables).toBeNull();
  });

  it('returns the body of a template', () => {
    const wrapper = shallowMount(TemplateParser, {
      props: { template: templates[1] },
      global: globalOpts,
    });
    const expectedOutput = templates[1].components.find(
      i => i.type === 'BODY'
    ).text;
    expect(wrapper.vm.templateString).toEqual(expectedOutput);
  });

  it('generates the templates from variable input', async () => {
    const wrapper = shallowMount(TemplateParser, {
      props: { template: templates[0] },
      data: () => ({ processedParams: {} }),
      global: globalOpts,
    });
    await wrapper.setData({ processedParams: { 1: 'abc', 2: 'xyz', 3: 'qwerty' } });
    await wrapper.vm.$nextTick();
    const expectedOutput =
      'Esta é a sua confirmação de voo para abc-xyz em qwerty.';
    expect(wrapper.vm.processedString).toEqual(expectedOutput);
  });
});
