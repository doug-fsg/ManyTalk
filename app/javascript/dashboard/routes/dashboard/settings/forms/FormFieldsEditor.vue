<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import FormIconButton from './FormIconButton.vue';

const { t } = useI18n();

const props = defineProps({
  value: { type: Object, default: () => ({ fields: [] }) },
});

const emit = defineEmits(['input']);

const store = useStore();
const getters = useStoreGetters();

const showAddPanel = ref(false);
const localFields = ref([]);
const isSyncing = ref(false);

const definitionSource = computed(() => props.value || { fields: [] });

watch(
  definitionSource,
  def => {
    if (isSyncing.value) return;
    localFields.value = (def.fields || []).map(field => ({ ...field }));
  },
  { immediate: true, deep: true }
);

const contactAttributes = computed(() =>
  (getters['attributes/getAttributesByModel'].value('contact_attribute') || []).filter(
    a => !localFields.value.some(f => f.attribute_key === a.attribute_key)
  )
);

const NATIVE_OPTIONS = [
  { key: 'name', field: 'name', label: 'Nome', type: 'native' },
  { key: 'email', field: 'email', label: 'E-mail', type: 'native' },
  { key: 'phone_number', field: 'phone_number', label: 'Telefone', type: 'native' },
];

const availableNative = computed(() =>
  NATIVE_OPTIONS.filter(opt => !localFields.value.some(f => f.field === opt.field))
);

const canAddFields = computed(
  () => availableNative.value.length > 0 || contactAttributes.value.length > 0
);

onMounted(() => {
  const attrs = getters['attributes/getAttributesByModel'].value('contact_attribute');
  if (!attrs || !attrs.length) {
    store.dispatch('attributes/get');
  }
});

const syncDefinition = () => {
  isSyncing.value = true;
  emit('input', {
    ...definitionSource.value,
    fields: localFields.value.map(field => ({ ...field })),
  });
  isSyncing.value = false;
};

const moveUp = index => {
  if (index === 0) return;
  const arr = [...localFields.value];
  [arr[index - 1], arr[index]] = [arr[index], arr[index - 1]];
  localFields.value = arr;
  syncDefinition();
};

const moveDown = index => {
  if (index >= localFields.value.length - 1) return;
  const arr = [...localFields.value];
  [arr[index], arr[index + 1]] = [arr[index + 1], arr[index]];
  localFields.value = arr;
  syncDefinition();
};

const removeField = index => {
  localFields.value = localFields.value.filter((_, i) => i !== index);
  syncDefinition();
};

const toggleRequired = index => {
  localFields.value = localFields.value.map((f, i) =>
    i === index ? { ...f, required: !f.required } : f
  );
  syncDefinition();
};

const updateLabel = (index, label) => {
  localFields.value = localFields.value.map((f, i) =>
    i === index ? { ...f, label } : f
  );
};

const addNativeField = opt => {
  localFields.value = [
    ...localFields.value,
    { key: opt.key, type: 'native', field: opt.field, label: opt.label, required: false },
  ];
  showAddPanel.value = false;
  syncDefinition();
};

const addCustomAttribute = attr => {
  localFields.value = [
    ...localFields.value,
    {
      key: `cf_${attr.attribute_key}`,
      type: 'custom_attribute',
      attribute_key: attr.attribute_key,
      attribute_model: 'contact_attribute',
      label: attr.attribute_display_name || attr.attribute_key,
      required: false,
    },
  ];
  showAddPanel.value = false;
  syncDefinition();
};

const toggleAddPanel = () => {
  if (!canAddFields.value) return;
  showAddPanel.value = !showAddPanel.value;
};

const typeIcon = field => {
  if (field.field === 'email' || field.key === 'email') return 'mail';
  if (field.field === 'phone_number' || field.key === 'phone_number') return 'call';
  if (field.type === 'custom_attribute') return 'tag';
  return 'person';
};
</script>

<template>
  <div class="space-y-1">
    <div
      v-for="(field, index) in localFields"
      :key="field.key"
      class="flex items-center gap-2 px-3 py-2 bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700 rounded-lg group hover:border-slate-200 dark:hover:border-slate-600 transition-colors duration-150"
    >
      <fluent-icon
        :icon="typeIcon(field)"
        size="14"
        class="text-slate-400 dark:text-slate-500 shrink-0"
        aria-hidden="true"
      />

      <input
        :value="field.label"
        type="text"
        class="flex-1 text-sm bg-transparent border-none outline-none text-slate-800 dark:text-slate-200 placeholder-slate-400 min-w-0"
        @input="updateLabel(index, $event.target.value)"
        @blur="syncDefinition"
      />

      <div class="flex items-center gap-0.5 shrink-0">
        <FormIconButton
          icon="chevron-up"
          :tooltip="t('ACCOUNT_FORM.FIELDS.MOVE_UP')"
          :disabled="index === 0"
          @click="moveUp(index)"
        />
        <FormIconButton
          icon="chevron-down"
          :tooltip="t('ACCOUNT_FORM.FIELDS.MOVE_DOWN')"
          :disabled="index === localFields.length - 1"
          @click="moveDown(index)"
        />
        <FormIconButton
          icon="star-emphasis"
          :color-scheme="field.required ? 'primary' : 'secondary'"
          :tooltip="field.required ? t('ACCOUNT_FORM.FIELDS.REQUIRED') : t('ACCOUNT_FORM.FIELDS.OPTIONAL')"
          @click="toggleRequired(index)"
        />
        <FormIconButton
          icon="dismiss"
          color-scheme="alert"
          :tooltip="t('ACCOUNT_FORM.FIELDS.REMOVE')"
          @click="removeField(index)"
        />
      </div>
    </div>

    <div v-if="!localFields.length" class="flex flex-col items-center gap-1 py-5 text-center">
      <fluent-icon
        icon="document"
        size="22"
        class="text-slate-300 dark:text-slate-600"
        aria-hidden="true"
      />
      <p class="text-[11px] text-slate-400">
        {{ t('ACCOUNT_FORM.FIELDS.EMPTY') }}
      </p>
    </div>

    <div class="pt-1">
      <FormIconButton
        icon="add-circle"
        color-scheme="primary"
        :tooltip="t('ACCOUNT_FORM.FIELDS.ADD_TOOLTIP')"
        :disabled="!canAddFields"
        @click="toggleAddPanel"
      />

      <div
        v-if="showAddPanel && canAddFields"
        class="mt-2 w-full max-w-md border border-slate-200 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 shadow-sm overflow-hidden"
      >
        <div v-if="availableNative.length" class="px-3 py-2 text-[10px] font-medium tracking-wide text-slate-400 uppercase">
          {{ t('ACCOUNT_FORM.FIELDS.NATIVE') }}
        </div>
        <button
          v-for="opt in availableNative"
          :key="opt.key"
          type="button"
          class="flex items-center gap-2 w-full px-4 py-2.5 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 cursor-pointer text-left"
          @click="addNativeField(opt)"
        >
          <fluent-icon :icon="typeIcon(opt)" size="13" class="text-slate-400 shrink-0" aria-hidden="true" />
          {{ opt.label }}
        </button>

        <div
          v-if="contactAttributes.length"
          class="px-3 py-2 text-[10px] font-medium tracking-wide text-slate-400 uppercase border-t border-slate-100 dark:border-slate-700"
        >
          {{ t('ACCOUNT_FORM.FIELDS.CUSTOM') }}
        </div>
        <button
          v-for="attr in contactAttributes"
          :key="attr.attribute_key"
          type="button"
          class="flex items-center gap-2 w-full px-4 py-2.5 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 cursor-pointer text-left"
          @click="addCustomAttribute(attr)"
        >
          <fluent-icon icon="tag" size="13" class="text-slate-400 shrink-0" aria-hidden="true" />
          {{ attr.attribute_display_name || attr.attribute_key }}
        </button>
      </div>

      <p v-else-if="!canAddFields" class="pt-1 text-[11px] text-slate-400">
        {{ t('ACCOUNT_FORM.FIELDS.ALL_ADDED') }}
      </p>
    </div>
  </div>
</template>
