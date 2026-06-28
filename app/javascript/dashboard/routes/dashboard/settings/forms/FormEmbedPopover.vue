<script setup>
import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';
import FormIconButton from './FormIconButton.vue';

const props = defineProps({
  publicUrl: { type: String, required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const embedSnippet = computed(() =>
  `<iframe src="${props.publicUrl}" width="100%" height="600" frameborder="0" allow="clipboard-write" title="Formulário"></iframe>`
);

const copyEmbed = async () => {
  try {
    await navigator.clipboard.writeText(embedSnippet.value);
    useAlert(t('ACCOUNT_FORM.EMBED.COPY_SUCCESS'));
  } catch {
    useAlert(embedSnippet.value);
  }
};
</script>

<template>
  <div
    class="absolute right-0 top-full z-20 mt-1 w-96 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-lg p-4"
  >
    <div class="flex items-center justify-between mb-3">
      <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
        {{ $t('ACCOUNT_FORM.EMBED.TITLE') }}
      </p>
      <FormIconButton icon="dismiss" tooltip="Fechar" @click="emit('close')" />
    </div>

    <pre
      class="p-3 text-xs font-mono bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg overflow-x-auto whitespace-pre-wrap break-all text-slate-700 dark:text-slate-300"
    >{{ embedSnippet }}</pre>

    <div class="flex justify-end mt-3">
      <FormIconButton
        icon="copy"
        color-scheme="primary"
        :tooltip="$t('ACCOUNT_FORM.EMBED.COPY_TOOLTIP')"
        @click="copyEmbed"
      />
    </div>
  </div>
</template>
