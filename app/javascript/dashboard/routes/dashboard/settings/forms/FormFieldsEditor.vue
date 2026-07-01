<script setup>
import { ref, watch } from 'vue';
import draggable from 'vuedraggable';
import FormFieldCard from './FormFieldCard.vue';

const props = defineProps({
  fields: { type: Array, default: () => [] },
  selectedIndex: { type: Number, default: -1 },
});

const emit = defineEmits([
  'reorder',
  'remove',
  'toggle-required',
  'update-label',
  'sync',
  'select',
]);

const localFields = ref([...props.fields]);

watch(
  () => props.fields,
  val => {
    localFields.value.splice(0, localFields.value.length, ...val);
  },
  { deep: true }
);

const onDragEnd = () => {
  emit('reorder', [...localFields.value]);
};
</script>

<template>
  <div class="flex flex-col h-full">
    <div class="mb-4 shrink-0">
      <p class="text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('ACCOUNT_FORM.FIELD_LIST.TITLE') }}
      </p>
      <p class="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
        {{ $t('ACCOUNT_FORM.FIELD_LIST.HINT') }}
      </p>
    </div>

    <div
      v-if="!localFields.length"
      class="flex flex-col items-center justify-center gap-3 py-12 px-4 border-2 border-dashed border-slate-200 dark:border-slate-700 rounded-xl text-center"
    >
      <fluent-icon
        icon="document"
        size="28"
        class="text-slate-300 dark:text-slate-600"
        aria-hidden="true"
      />
      <p class="text-sm text-slate-400 dark:text-slate-500">
        {{ $t('ACCOUNT_FORM.FIELD_LIST.EMPTY') }}
      </p>
      <p class="text-xs text-slate-300 dark:text-slate-600">
        {{ $t('ACCOUNT_FORM.FIELD_LIST.EMPTY_HINT') }}
      </p>
    </div>

    <draggable
      v-if="localFields.length"
      :list="localFields"
      handle=".drag-handle"
      tag="div"
      class="flex flex-col gap-2"
      ghost-class="opacity-40"
      animation="180"
      @end="onDragEnd"
    >
      <FormFieldCard
        v-for="(field, index) in localFields"
        :key="field.key"
        :field="field"
        :is-selected="selectedIndex === index"
        @select="emit('select', index)"
        @remove="emit('remove', index)"
        @toggle-required="emit('toggle-required', index)"
        @update-label="label => emit('update-label', index, label)"
        @sync="emit('sync')"
      />
    </draggable>

    <div
      v-if="localFields.length"
      class="mt-3 flex items-center justify-center gap-2 py-2.5 border-2 border-dashed border-slate-100 dark:border-slate-800 rounded-xl text-xs text-slate-300 dark:text-slate-600"
    >
      <fluent-icon icon="add-circle" size="12" aria-hidden="true" />
      {{ $t('ACCOUNT_FORM.FIELD_LIST.DROP_HINT') }}
    </div>
  </div>
</template>
