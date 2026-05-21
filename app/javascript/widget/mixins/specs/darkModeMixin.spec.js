import { shallowMount } from '@vue/test-utils';
import darkModeMixin from '../darkModeMixin';
import { createStore } from 'vuex';

const darkModeValues = ['light', 'auto'];

describe('darkModeMixin', () => {
  let getters;
  let store;
  beforeEach(() => {
    getters = {
      'appConfig/darkMode': () => darkModeValues[0],
    };
    store = createStore({ getters });
  });

  it('if light theme', () => {
    const Component = {
      render() {},
      mixins: [darkModeMixin],
    };
    const wrapper = shallowMount(Component, { global: { plugins: [store] } });
    expect(wrapper.vm.$dm('bg-100', 'bg-600')).toBe('bg-100');
  });

  it('if auto theme', () => {
    getters = {
      'appConfig/darkMode': () => darkModeValues[2],
    };
    store = createStore({ getters });

    const Component = {
      render() {},
      mixins: [darkModeMixin],
    };
    const wrapper = shallowMount(Component, { global: { plugins: [store] } });
    expect(wrapper.vm.$dm('bg-100', 'bg-600')).toBe('bg-100 bg-600');
  });
});
