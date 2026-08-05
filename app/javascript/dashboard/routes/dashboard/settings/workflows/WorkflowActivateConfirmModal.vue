<script setup>
import { computed, ref } from 'vue';
import { useRouter } from 'dashboard/composables/route';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  confirmLabel: {
    type: String,
    default: '',
  },
  cancelLabel: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const router = useRouter();

const show = ref(false);
const conflictingAutomations = ref([]);
let resolvePromise;

const hasConflicts = computed(() => conflictingAutomations.value.length > 0);

const resolvedConfirmLabel = computed(
  () => props.confirmLabel || t('WORKFLOW.ACTIVATE_MODAL.CONFIRM')
);
const resolvedCancelLabel = computed(
  () => props.cancelLabel || t('WORKFLOW.ACTIVATE_MODAL.CANCEL')
);

const showConfirmation = ({ conflictingAutomations: conflicts = [] } = {}) => {
  conflictingAutomations.value = conflicts;
  show.value = true;
  return new Promise(resolve => {
    resolvePromise = resolve;
  });
};

const close = confirmed => {
  show.value = false;
  resolvePromise?.(confirmed);
  resolvePromise = undefined;
};

const confirm = () => close(true);
const cancel = () => close(false);

const goToAutomations = () => {
  router.push({ name: 'automation_list' });
};

defineExpose({ showConfirmation });
</script>

<template>
  <woot-modal :show="show" :on-close="cancel" :close-on-backdrop-click="false">
    <div class="flex w-full flex-col">
      <woot-modal-header
        :header-title="$t('WORKFLOW.ACTIVATE_MODAL.TITLE')"
        :header-content="$t('WORKFLOW.ACTIVATE_MODAL.DESCRIPTION')"
      />

      <div
        v-if="hasConflicts"
        class="mx-8 mb-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 dark:border-amber-800/50 dark:bg-amber-950/30"
      >
        <div class="flex items-start gap-2">
          <fluent-icon
            icon="warning"
            size="16"
            class="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400"
            aria-hidden="true"
          />
          <div class="min-w-0">
            <p class="text-sm font-medium text-amber-900 dark:text-amber-100">
              {{ $t('WORKFLOW.ACTIVATE_MODAL.CONFLICT_TITLE') }}
            </p>
            <p class="mt-1 text-xs leading-relaxed text-amber-800 dark:text-amber-200">
              {{ $t('WORKFLOW.ACTIVATE_MODAL.CONFLICT_BODY', { names: conflictingAutomations.join(', ') }) }}
            </p>
            <button
              type="button"
              class="mt-2 text-xs font-medium text-woot-500 hover:text-woot-600 dark:text-woot-400"
              @click="goToAutomations"
            >
              {{ $t('WORKFLOW.ACTIVATE_MODAL.CONFLICT_LINK') }}
            </button>
          </div>
        </div>
      </div>

      <div class="flex flex-row justify-end gap-2 px-6 py-4">
        <woot-button variant="clear" @click="cancel">
          {{ resolvedCancelLabel }}
        </woot-button>
        <woot-button @click="confirm">
          {{ hasConflicts ? $t('WORKFLOW.ACTIVATE_MODAL.CONFIRM_RISK') : resolvedConfirmLabel }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
