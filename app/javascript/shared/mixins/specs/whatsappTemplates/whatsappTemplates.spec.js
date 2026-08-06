import TemplateParser from '../../../../dashboard/components/widgets/conversation/WhatsappTemplates/TemplateParser.vue';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { templates } from './fixtures';
const localVue = createLocalVue();
import VueI18n from 'vue-i18n';
import Vuelidate from 'vuelidate';
import i18n from 'dashboard/i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';

vi.mock('dashboard/composables/useUISettings');

localVue.use(VueI18n);
localVue.use(Vuelidate);

const i18nConfig = new VueI18n({ locale: 'en', messages: i18n });
const config = {
  localVue,
  i18n: i18nConfig,
  stubs: {
    WootButton: { template: '<button />' },
    WootInput: { template: '<input />' },
    TemplateVariableInput: { template: '<input />' },
  },
  mocks: {
    $store: {
      getters: {
        'accounts/isFeatureEnabledonAccount': () => false,
        getCurrentAccountId: () => 1,
      },
    },
  },
};

beforeEach(() => {
  useUISettings.mockReturnValue({
    uiSettings: {},
    updateUISettings: vi.fn(),
  });
});

describe('#WhatsAppTemplates', () => {
  it('returns all variables from a template string', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[0] },
    });
    expect(wrapper.vm.bodyVariables).toEqual(['1', '2', '3']);
  });

  it('returns no variables from a template string if it does not contain variables', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[12] },
    });
    expect(wrapper.vm.bodyVariables).toEqual([]);
  });

  it('returns the body of a template', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[1] },
    });
    const expectedOutput = templates[1].components.find(
      i => i.type === 'BODY'
    ).text;
    expect(wrapper.vm.processedString).toEqual(expectedOutput);
  });

  it('generates the templates from variable input', async () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[0] },
    });
    await wrapper.setData({
      processedParams: {
        body: { 1: 'abc', 2: 'xyz', 3: 'qwerty' },
        header: {
          media_url: 'https://cdn.example.com/boarding.pdf',
          media_type: 'document',
          media_name: 'boarding.pdf',
        },
      },
    });
    await wrapper.vm.$nextTick();
    const expectedOutput =
      'Esta é a sua confirmação de voo para abc-xyz em qwerty.';
    expect(wrapper.vm.processedString).toEqual(expectedOutput);
  });

  it('asks for media url on IMAGE/VIDEO/DOCUMENT templates without feature flag', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[0] },
    });

    expect(wrapper.vm.hasMediaHeader).toBe(true);
    expect(wrapper.vm.requiresDynamicMediaUrl).toBe(true);
    expect(wrapper.vm.useEnhancedTemplateFormat).toBe(true);
    expect(wrapper.vm.processedParams.header).toEqual({
      media_url: '',
      media_type: 'document',
      media_name: '',
    });
  });

  it('uses enhanced params for text-only templates', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[1] },
    });

    expect(wrapper.vm.hasMediaHeader).toBe(false);
    expect(wrapper.vm.useEnhancedTemplateFormat).toBe(true);
    expect(wrapper.vm.processedParams).toEqual({ body: { '1': '' } });
  });

  it('exposes text header variables separately from media headers', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[13] },
    });

    expect(wrapper.vm.textHeaderVariables).toEqual(['1']);
    expect(wrapper.vm.requiresDynamicMediaUrl).toBe(false);
    expect(wrapper.vm.processedParams.header).toEqual({ '1': '' });
  });

  it('renders text header preview with interpolated values', async () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[13] },
    });

    await wrapper.setData({
      processedParams: {
        header: { '1': 'Jane' },
        body: { '1': 'Monday' },
      },
    });
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.renderedHeader).toEqual('Welcome Jane');
    expect(wrapper.vm.processedString).toEqual(
      'Your appointment is on Monday.'
    );
  });

  it('builds named body variables for NAMED templates', () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[14] },
    });

    expect(wrapper.vm.bodyVariables).toEqual(['first_name', 'order_id']);
    expect(wrapper.vm.processedParams.body).toEqual({
      first_name: '',
      order_id: '',
    });
  });

  it('blocks send when required fields are incomplete', async () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[13] },
    });

    expect(wrapper.vm.isFormInvalid).toBe(true);

    await wrapper.setData({
      processedParams: {
        header: { '1': 'Jane' },
        body: { '1': 'Monday' },
      },
    });
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.isFormInvalid).toBe(false);
  });

  it('regenerates params when template changes', async () => {
    const wrapper = shallowMount(TemplateParser, {
      ...config,
      propsData: { template: templates[1] },
    });

    await wrapper.setProps({ template: templates[14] });
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.processedParams.body).toEqual({
      first_name: '',
      order_id: '',
    });
  });
});
