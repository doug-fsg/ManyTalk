<script setup>
import { computed, nextTick, ref, watch } from 'vue';

const props = defineProps({
  title: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  hint: { type: String, default: '' },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update:title']);

const isEditing = ref(false);
const draft = ref('');
const inputRef = ref(null);

const displayTitle = computed(() => {
  const value = (props.title || '').trim();
  return value || props.placeholder || '';
});

watch(
  () => props.title,
  value => {
    if (!isEditing.value) draft.value = value || '';
  },
  { immediate: true }
);

const startEdit = async () => {
  if (props.readOnly) return;
  draft.value = props.title || '';
  isEditing.value = true;
  await nextTick();
  const el = inputRef.value;
  if (el && el.focus) {
    el.focus();
    el.select();
  }
};

const commit = () => {
  if (!isEditing.value) return;
  isEditing.value = false;
  const next = (draft.value || '').trim();
  if (next !== (props.title || '').trim()) {
    emit('update:title', next);
  }
};

const onKeydown = event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    commit();
  } else if (event.key === 'Escape') {
    event.preventDefault();
    draft.value = props.title || '';
    isEditing.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col items-start px-8 pt-8 pb-0 min-w-0">
    <div class="min-w-0 max-w-[16rem] sm:max-w-[20rem] pr-10">
      <input
        v-if="isEditing"
        ref="inputRef"
        v-model="draft"
        type="text"
        name="workflow-node-modal-title"
        maxlength="60"
        class="reset-base w-full max-w-[16rem] sm:max-w-[20rem] m-0 h-auto px-1.5 py-0.5 rounded-md text-base font-semibold leading-6 text-slate-800 dark:text-slate-50 bg-slate-50 dark:bg-slate-700/60 border border-woot-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
        :placeholder="placeholder"
        autocomplete="off"
        spellcheck="false"
        :aria-label="placeholder"
        @blur="commit"
        @keydown="onKeydown"
      />
      <button
        v-else
        type="button"
        class="reset-base max-w-full m-0 p-0 text-left text-base font-semibold leading-6 text-slate-800 dark:text-slate-50 bg-transparent border-0 rounded-md cursor-pointer hover:text-woot-600 dark:hover:text-woot-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
        :disabled="readOnly"
        :title="$t('WORKFLOW.EDITOR.STEP_LABEL_EDIT_HINT')"
        @click="startEdit"
      >
        <span class="truncate block">{{ displayTitle }}</span>
      </button>
    </div>
    <p
      v-if="hint"
      class="w-full mt-2 text-sm leading-5 break-words text-slate-600 dark:text-slate-300"
    >
      {{ hint }}
    </p>
  </div>
</template>
