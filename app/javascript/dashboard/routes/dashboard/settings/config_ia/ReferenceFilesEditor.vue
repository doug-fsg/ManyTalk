<script setup>
import { computed, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import {
  isValidTokenKey,
  slugFromName,
  tokenFor,
  tokenFromFilename,
} from './aiAttendantReferenceVariables';

const emit = defineEmits(['update:variables', 'update:savePayload']);

const MAX_FILES = 10;
const MAX_BYTES = 10 * 1024 * 1024;

const props = defineProps({
  initialFiles: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const fileInputRef = ref(null);
const isDragging = ref(false);
const savedFiles = ref([]);
const pendingFiles = ref([]);
const removeIds = ref([]);
let localId = 0;

const allVisible = computed(() => [
  ...savedFiles.value,
  ...pendingFiles.value,
]);

const canAddMore = computed(() => allVisible.value.length < MAX_FILES);

const variableItems = computed(() =>
  allVisible.value
    .filter(item => isValidTokenKey(item.tokenKey) && !item.uploading)
    .map(item => ({
      key: `anexo:${item.tokenKey}`,
      label: `anexo:${item.tokenKey}`,
      description: item.filename,
      token: item.token,
      tokenKey: item.tokenKey,
      filename: item.filename,
    }))
);

watch(
  variableItems,
  value => {
    emit('update:variables', value);
  },
  { immediate: true }
);

const formatSize = bytes => {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

const isImage = file => (file.contentType || '').startsWith('image/');

const usedKeys = excludeKey =>
  allVisible.value
    .map(item => item.tokenKey)
    .filter(key => key && key !== excludeKey);

const hydrate = files => {
  const used = [];
  savedFiles.value = (files || []).map(file => {
    const fromApi = file.token
      ? {
          token: file.token,
          tokenKey: file.token.replace(/^\{\{anexo:|\}\}$/g, ''),
        }
      : tokenFromFilename(file.filename, used);
    used.push(fromApi.tokenKey);
    return {
      key: `saved-${file.id}`,
      id: file.id,
      blobId: file.blob_id,
      filename: file.filename,
      token: fromApi.token,
      tokenKey: fromApi.tokenKey,
      nameDraft: fromApi.tokenKey,
      contentType: file.content_type,
      byteSize: file.byte_size,
      url: file.url,
      previewUrl: (file.content_type || '').startsWith('image/')
        ? file.url
        : '',
      uploading: false,
      persisted: true,
    };
  });
  pendingFiles.value = [];
  removeIds.value = [];
};

watch(
  () => props.initialFiles,
  value => {
    hydrate(value);
  },
  { immediate: true }
);

const isUploading = computed(() =>
  pendingFiles.value.some(item => item.uploading)
);

const hasInvalidNames = () =>
  allVisible.value.some(
    item => !item.uploading && !isValidTokenKey(item.tokenKey)
  );

const namesByBlobId = () =>
  Object.fromEntries(
    pendingFiles.value
      .filter(item => item.blobId && isValidTokenKey(item.tokenKey))
      .map(item => [String(item.blobId), item.tokenKey])
  );

const namesByAttachmentId = () =>
  Object.fromEntries(
    savedFiles.value
      .filter(item => item.id && isValidTokenKey(item.tokenKey))
      .map(item => [String(item.id), item.tokenKey])
  );

const getSavePayload = () => ({
  reference_file_blob_ids: pendingFiles.value
    .filter(item => item.blobId && isValidTokenKey(item.tokenKey))
    .map(item => item.blobId),
  remove_reference_file_ids: [...removeIds.value],
  reference_file_names: namesByBlobId(),
  reference_file_attachment_names: namesByAttachmentId(),
});

const emitSavePayload = () => {
  emit('update:savePayload', getSavePayload());
};

watch([pendingFiles, savedFiles, removeIds], emitSavePayload, {
  deep: true,
  immediate: true,
});

defineExpose({
  getSavePayload,
  isUploadingFiles: () => isUploading.value,
  hasInvalidNames,
});

const openPicker = () => {
  if (!canAddMore.value) return;
  fileInputRef.value?.click();
};

const onDragOver = () => {
  if (canAddMore.value) isDragging.value = true;
};

const onDragLeave = () => {
  isDragging.value = false;
};

const addFiles = fileList => {
  const incoming = Array.from(fileList || []);
  incoming.forEach(file => {
    if (!canAddMore.value) {
      useAlert(t('AI_ATTENDANT.FORM.FILES.MAX_ERROR'));
      return;
    }
    if (file.size > MAX_BYTES) {
      useAlert(t('AI_ATTENDANT.FORM.FILES.SIZE_ERROR', { name: file.name }));
      return;
    }
    uploadSelected(file);
  });
};

const suggestedName = filename => {
  const slug = slugFromName(filename);
  if (!isValidTokenKey(slug)) return '';
  if (!usedKeys().includes(slug)) return slug;
  return '';
};

const commitName = (file, raw) => {
  const slug = slugFromName(raw);
  file.nameDraft = slug;
  if (!isValidTokenKey(slug)) {
    file.tokenKey = '';
    file.token = '';
    return;
  }
  if (usedKeys(file.tokenKey).includes(slug)) {
    useAlert(t('AI_ATTENDANT.FORM.FILES.NAME_TAKEN', { name: slug }));
    file.nameDraft = file.tokenKey;
    return;
  }
  file.tokenKey = slug;
  file.token = tokenFor(slug);
};

const uploadSelected = async file => {
  localId += 1;
  const name = suggestedName(file.name);
  const item = {
    key: `pending-${localId}`,
    id: null,
    blobId: null,
    filename: file.name,
    token: name ? tokenFor(name) : '',
    tokenKey: name,
    nameDraft: name,
    contentType: file.type,
    byteSize: file.size,
    url: '',
    previewUrl: file.type.startsWith('image/') ? URL.createObjectURL(file) : '',
    uploading: true,
    persisted: false,
  };
  pendingFiles.value.push(item);

  try {
    const uploaded = await uploadFile(file);
    item.blobId = uploaded.blobId;
    item.url = uploaded.fileUrl;
    item.uploading = false;
  } catch (error) {
    pendingFiles.value = pendingFiles.value.filter(
      entry => entry.key !== item.key
    );
    useAlert(t('AI_ATTENDANT.FORM.FILES.UPLOAD_ERROR', { name: file.name }));
  }
};

const removeFile = file => {
  if (file.persisted && file.id) {
    removeIds.value.push(file.id);
    savedFiles.value = savedFiles.value.filter(item => item.key !== file.key);
    return;
  }
  pendingFiles.value = pendingFiles.value.filter(item => item.key !== file.key);
};

const onInputChange = event => {
  addFiles(event.target.files);
  event.target.value = '';
};

const onDrop = event => {
  isDragging.value = false;
  addFiles(event.dataTransfer?.files);
};

const copyToken = async file => {
  if (!file.token) return;
  try {
    await navigator.clipboard.writeText(file.token);
    useAlert(t('AI_ATTENDANT.FORM.FILES.COPIED', { token: file.token }));
  } catch (error) {
    useAlert(t('AI_ATTENDANT.FORM.FILES.COPY_ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-sm font-medium text-slate-800 dark:text-slate-200 m-0">
      {{ $t('AI_ATTENDANT.FORM.FILES.LABEL') }}
    </p>

    <button
      type="button"
      class="flex flex-col items-center justify-center w-full px-4 py-6 rounded-xl border border-dashed transition-colors"
      :class="
        isDragging
          ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/20'
          : 'border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800/40 hover:border-woot-400'
      "
      :disabled="!canAddMore"
      @click="openPicker"
      @dragover.prevent="onDragOver"
      @dragleave.prevent="onDragLeave"
      @drop.prevent="onDrop"
    >
      <fluent-icon
        icon="attach"
        size="20"
        class="text-slate-400 dark:text-slate-500 mb-2"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('AI_ATTENDANT.FORM.FILES.DROP_LABEL') }}
      </span>
      <span class="text-xs text-slate-500 dark:text-slate-400 mt-1">
        {{ $t('AI_ATTENDANT.FORM.FILES.DROP_HINT') }}
      </span>
    </button>

    <input
      ref="fileInputRef"
      type="file"
      class="hidden"
      multiple
      accept="image/*,video/*,audio/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx"
      @change="onInputChange"
    />

    <ul v-if="allVisible.length" class="flex flex-col gap-2 m-0 p-0 list-none">
      <li
        v-for="file in allVisible"
        :key="file.key"
        class="flex items-center gap-3 px-3 py-2 rounded-xl border border-solid border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-900"
      >
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg overflow-hidden bg-slate-50 dark:bg-slate-800 shrink-0"
        >
          <img
            v-if="isImage(file) && file.previewUrl"
            :src="file.previewUrl"
            :alt="file.filename"
            class="w-full h-full object-cover"
          />
          <fluent-icon
            v-else
            icon="document"
            size="18"
            class="text-slate-400"
          />
        </div>
        <div class="min-w-0 flex-1">
          <p
            class="mb-0 text-xs text-slate-500 dark:text-slate-400 truncate"
          >
            {{ file.filename }}
            <span v-if="file.uploading">
              · {{ $t('AI_ATTENDANT.FORM.FILES.UPLOADING') }}
            </span>
            <span v-else> · {{ formatSize(file.byteSize) }}</span>
          </p>
          <label class="mb-0 mt-1 block text-xs text-slate-600 dark:text-slate-300">
            {{ $t('AI_ATTENDANT.FORM.FILES.NAME_LABEL') }}
            <input
              :value="file.nameDraft"
              type="text"
              maxlength="24"
              class="mt-1 w-full"
              :disabled="file.uploading"
              :placeholder="$t('AI_ATTENDANT.FORM.FILES.NAME_PLACEHOLDER')"
              @input="file.nameDraft = $event.target.value"
              @blur="commitName(file, file.nameDraft)"
              @keydown.enter.prevent="commitName(file, file.nameDraft)"
            />
          </label>
          <p
            v-if="!file.uploading && !isValidTokenKey(file.tokenKey)"
            class="mb-0 mt-1 text-xs text-red-500"
          >
            {{ $t('AI_ATTENDANT.FORM.FILES.NAME_ERROR') }}
          </p>
          <button
            v-if="file.token && !file.uploading"
            type="button"
            class="mt-1 inline-flex items-center px-2 py-0.5 rounded-md text-xs font-mono bg-slate-50 dark:bg-slate-800 text-woot-700 dark:text-woot-300 border border-solid border-slate-100 dark:border-slate-700"
            @click="copyToken(file)"
          >
            {{ file.token }}
          </button>
        </div>
        <woot-button
          type="button"
          variant="clear"
          color-scheme="secondary"
          size="tiny"
          icon="dismiss"
          :disabled="file.uploading"
          :aria-label="$t('AI_ATTENDANT.FORM.FILES.REMOVE')"
          @click="removeFile(file)"
        />
      </li>
    </ul>
  </div>
</template>
