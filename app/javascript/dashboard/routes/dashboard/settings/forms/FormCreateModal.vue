<script setup>
import { ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';

const emit = defineEmits(['close', 'created']);
const store = useStore();
const { t } = useI18n();

const name = ref('');
const slug = ref('');
const isSubmitting = ref(false);

const onSubmit = async () => {
  if (!name.value.trim()) return;
  isSubmitting.value = true;
  try {
    const form = await store.dispatch('accountForms/create', {
      name: name.value.trim(),
      slug: slug.value.trim() || undefined,
    });
    emit('created', form);
  } catch {
    useAlert(t('ACCOUNT_FORM.CREATE.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <Modal :show="true" :on-close="() => emit('close')">
    <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
        {{ $t('ACCOUNT_FORM.CREATE.TITLE') }}
      </h3>
      <label class="flex flex-col gap-1 text-sm">
        <span>{{ $t('ACCOUNT_FORM.CREATE.NAME_LABEL') }}</span>
        <input
          v-model="name"
          type="text"
          class="px-3 py-2 border rounded-lg border-slate-200 dark:border-slate-700 dark:bg-slate-900"
          :placeholder="$t('ACCOUNT_FORM.CREATE.NAME_PLACEHOLDER')"
          required
        />
      </label>
      <label class="flex flex-col gap-1 text-sm">
        <span>{{ $t('ACCOUNT_FORM.CREATE.SLUG_LABEL') }}</span>
        <input
          v-model="slug"
          type="text"
          class="px-3 py-2 border rounded-lg border-slate-200 dark:border-slate-700 dark:bg-slate-900"
          :placeholder="$t('ACCOUNT_FORM.CREATE.SLUG_PLACEHOLDER')"
        />
      </label>
      <div class="flex justify-end gap-2">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          type="button"
          @click="emit('close')"
        >
          {{ $t('COMMON.CANCEL') }}
        </woot-button>
        <woot-button type="submit" :is-loading="isSubmitting">
          {{ $t('ACCOUNT_FORM.CREATE.SUBMIT') }}
        </woot-button>
      </div>
    </form>
  </Modal>
</template>
