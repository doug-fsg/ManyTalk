import { ref, computed, unref } from 'vue';
import { linkageFromForm } from './formWorkflowLinkage';

export const useFormListFilters = formsSource => {
  const searchQuery = ref('');
  const statusFilter = ref('');
  const flowFilter = ref('');

  const linkageByFormId = computed(() => {
    const map = {};
    (unref(formsSource) || []).forEach(form => {
      map[form.id] = linkageFromForm(form);
    });
    return map;
  });

  const filteredForms = computed(() => {
    let list = [...(unref(formsSource) || [])];
    const query = searchQuery.value.trim().toLowerCase();

    if (query) {
      list = list.filter(
        form =>
          (form.name || '').toLowerCase().includes(query) ||
          (form.slug || '').toLowerCase().includes(query)
      );
    }

    if (statusFilter.value) {
      list = list.filter(form => form.status === statusFilter.value);
    }

    if (flowFilter.value === 'no_active_flow') {
      list = list.filter(
        form => linkageByFormId.value[form.id]?.state !== 'automates'
      );
    }

    return list;
  });

  const hasActiveFilters = computed(
    () =>
      Boolean(searchQuery.value.trim()) ||
      Boolean(statusFilter.value) ||
      flowFilter.value === 'no_active_flow'
  );

  return {
    searchQuery,
    statusFilter,
    flowFilter,
    filteredForms,
    linkageByFormId,
    hasActiveFilters,
  };
};
