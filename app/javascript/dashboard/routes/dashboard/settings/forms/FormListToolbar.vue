<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  searchQuery: { type: String, default: '' },
  statusFilter: { type: String, default: '' },
  flowFilter: { type: String, default: '' },
});

const emit = defineEmits([
  'update:searchQuery',
  'update:statusFilter',
  'update:flowFilter',
]);

const { t } = useI18n();
const showSearch = ref(Boolean(props.searchQuery));

const statusFilters = computed(() => [
  { value: '', label: t('ACCOUNT_FORM.LIST.FILTERS.ALL') },
  { value: 'draft', label: t('ACCOUNT_FORM.STATUS.DRAFT') },
  { value: 'published', label: t('ACCOUNT_FORM.STATUS.PUBLISHED') },
  { value: 'paused', label: t('ACCOUNT_FORM.STATUS.PAUSED') },
]);


const toggleNoAutomationFilter = () => {
  emit(
    'update:flowFilter',
    props.flowFilter === 'no_active_flow' ? '' : 'no_active_flow'
  );
};

const onSearchInput = event => {
  emit('update:searchQuery', event.target.value);
};

const onStatusFilter = value => {
  emit('update:statusFilter', value);
};
</script>

<template>
  <div class="flex items-center gap-2 mb-4 flex-wrap">
    <div class="flex items-center gap-1 flex-wrap">
      <button
        v-for="filter in statusFilters"
        :key="`status-${filter.value}`"
        type="button"
        class="px-3 py-1 text-xs font-medium rounded-lg transition-colors duration-200 cursor-pointer"
        :class="
          statusFilter === filter.value
            ? 'bg-woot-500 text-white'
            : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600'
        "
        @click="onStatusFilter(filter.value)"
      >
        {{ filter.label }}
      </button>
    </div>

    <button
      type="button"
      class="px-3 py-1 text-xs font-medium rounded-lg transition-colors duration-200 cursor-pointer"
      :class="
        flowFilter === 'no_active_flow'
          ? 'bg-woot-500 text-white'
          : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600'
      "
      @click="toggleNoAutomationFilter"
    >
      {{ $t('ACCOUNT_FORM.LIST.FILTERS.NO_AUTOMATION') }}
    </button>

    <div class="flex items-center gap-2">
      <button
        type="button"
        class="relative inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth cursor-pointer text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-50 dark:hover:bg-slate-700"
        :class="
          showSearch
            ? 'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-400'
            : ''
        "
        v-tooltip.top="
          showSearch ? '' : $t('ACCOUNT_FORM.LIST.FILTERS.SEARCH_PLACEHOLDER')
        "
        @click="showSearch = !showSearch"
      >
        <fluent-icon icon="search" size="14" />
      </button>
      <transition
        enter-active-class="transition ease-out duration-200"
        enter-from-class="opacity-0 -translate-x-2"
        enter-to-class="opacity-100 translate-x-0"
        leave-active-class="transition ease-in duration-150"
        leave-from-class="opacity-100 translate-x-0"
        leave-to-class="opacity-0 -translate-x-2"
      >
        <input
          v-show="showSearch"
          :value="searchQuery"
          type="search"
          :placeholder="$t('ACCOUNT_FORM.LIST.FILTERS.SEARCH_PLACEHOLDER')"
          class="px-3 py-1.5 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:placeholder-slate-400 w-48 transition-colors duration-150 ease-smooth"
          @input="onSearchInput"
        />
      </transition>
    </div>
  </div>
</template>
