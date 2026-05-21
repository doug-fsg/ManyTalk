import { computed, getCurrentInstance } from 'vue';

export function useI18n() {
  const instance = getCurrentInstance();
  const vm = instance?.proxy ?? instance;

  if (!vm) {
    throw new Error('useI18n must be called inside a component setup() function');
  }

  const locale = computed({
    get() {
      return vm.$i18n?.locale;
    },
    set(v) {
      if (vm.$i18n) vm.$i18n.locale = v;
    },
  });

  return {
    locale,
    t: vm.$t.bind(vm),
    tc: vm.$tc?.bind(vm),
    d: vm.$d?.bind(vm),
    te: vm.$te?.bind(vm),
    n: vm.$n?.bind(vm),
  };
}
