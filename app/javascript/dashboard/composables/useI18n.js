import { computed, getCurrentInstance } from 'vue';
import Vue from 'vue';

function resolveI18n(vm) {
  return vm?.$i18n || vm?.$root?.$i18n || null;
}

function resolveLocale(vm) {
  return (
    resolveI18n(vm)?.locale ||
    window.chatwootConfig?.selectedLocale ||
    'en'
  );
}

export function useI18n() {
  const instance = getCurrentInstance();
  const vm = instance?.proxy || instance || new Vue({});

  const locale = computed({
    get() {
      return resolveLocale(vm);
    },
    set(value) {
      const i18n = resolveI18n(vm);
      if (i18n) {
        i18n.locale = value;
      }
    },
  });

  return {
    locale,
    t: vm.$t.bind(vm),
    tc: vm.$tc.bind(vm),
    d: vm.$d.bind(vm),
    te: vm.$te.bind(vm),
    n: vm.$n.bind(vm),
  };
}
