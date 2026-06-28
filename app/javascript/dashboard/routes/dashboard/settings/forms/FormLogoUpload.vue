<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';
import FormIconButton from './FormIconButton.vue';

const MAX_FILE_SIZE_MB = 4;

const props = defineProps({
  value: { type: String, default: '' },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['input']);

const { t } = useI18n();

const fileInput = ref(null);
const isUploading = ref(false);
const localPreview = ref('');

const displayUrl = computed(() => localPreview.value || props.value);
const hasLogo = computed(() => Boolean(displayUrl.value));

const openPicker = () => {
  if (isUploading.value) return;
  fileInput.value?.click();
};

const onFileChange = async event => {
  const [file] = event.target.files || [];
  event.target.value = '';
  if (!file) return;

  if (!checkFileSizeLimit(file, MAX_FILE_SIZE_MB)) {
    useAlert(
      t('ACCOUNT_FORM.APPEARANCE.LOGO_SIZE_ERROR', { size: MAX_FILE_SIZE_MB })
    );
    return;
  }

  isUploading.value = true;
  localPreview.value = URL.createObjectURL(file);

  try {
    const { fileUrl } = await uploadFile(file, props.accountId);
    emit('input', fileUrl);
  } catch {
    useAlert(t('ACCOUNT_FORM.APPEARANCE.LOGO_UPLOAD_ERROR'));
  } finally {
    if (localPreview.value) {
      URL.revokeObjectURL(localPreview.value);
    }
    localPreview.value = '';
    isUploading.value = false;
  }
};

const removeLogo = () => {
  emit('input', '');
  localPreview.value = '';
};
</script>

<template>
  <div class="flex items-center gap-2">
    <button
      type="button"
      v-tooltip.top="
        hasLogo
          ? $t('ACCOUNT_FORM.APPEARANCE.LOGO_CHANGE_TOOLTIP')
          : $t('ACCOUNT_FORM.APPEARANCE.LOGO_UPLOAD_TOOLTIP')
      "
      class="flex items-center justify-center h-10 min-w-[2.5rem] px-2 rounded-lg border transition-colors duration-150 cursor-pointer"
      :class="
        hasLogo
          ? 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 hover:border-slate-300 dark:hover:border-slate-600'
          : 'border-dashed border-slate-200 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-800/30 hover:border-woot-300 dark:hover:border-woot-600'
      "
      :disabled="isUploading"
      :aria-label="$t('ACCOUNT_FORM.APPEARANCE.LOGO_UPLOAD_TOOLTIP')"
      @click="openPicker"
    >
      <img
        v-if="hasLogo && !isUploading"
        :src="displayUrl"
        alt=""
        class="h-7 max-w-[120px] object-contain"
      />
      <woot-spinner v-else-if="isUploading" size="tiny" />
      <fluent-icon
        v-else
        icon="image"
        size="18"
        class="text-slate-300 dark:text-slate-600"
        aria-hidden="true"
      />
    </button>

    <FormIconButton
      v-if="hasLogo && !isUploading"
      icon="dismiss"
      color-scheme="alert"
      :tooltip="$t('ACCOUNT_FORM.APPEARANCE.LOGO_REMOVE_TOOLTIP')"
      @click="removeLogo"
    />

    <input
      ref="fileInput"
      type="file"
      accept="image/png, image/jpeg, image/jpg, image/gif, image/webp"
      class="hidden"
      @change="onFileChange"
    />
  </div>
</template>
