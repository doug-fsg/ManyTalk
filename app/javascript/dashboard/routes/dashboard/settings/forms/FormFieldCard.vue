<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import FormIconButton from './FormIconButton.vue';

const props = defineProps({
  field: { type: Object, required: true },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits(['select', 'remove', 'toggle-required', 'update-label', 'sync']);

const { t } = useI18n();
const localLabel = ref(props.field.label);

watch(
  () => props.field.label,
  val => {
    localLabel.value = val;
  }
);

const NATIVE_ICONS = { name: 'person', email: 'mail', phone_number: 'call' };

const typeIcon = computed(() => {
  if (props.field.type === 'native') return NATIVE_ICONS[props.field.field] || 'document';
  return 'tag';
});

const typeLabel = computed(() => {
  if (props.field.type === 'native') {
    const labels = {
      name: t('ACCOUNT_FORM.FIELD_CARD.NAME_FULL'),
      email: t('ACCOUNT_FORM.NATIVE.EMAIL'),
      phone_number: t('ACCOUNT_FORM.NATIVE.PHONE'),
    };
    return labels[props.field.field] || t('ACCOUNT_FORM.FIELD_CARD.NATIVE_FIELD');
  }
  return t('ACCOUNT_FORM.FIELD_CARD.CUSTOM_ATTRIBUTE');
});

const requiredToggleIcon = computed(() =>
  props.field.required ? 'lock-closed' : 'checkmark-circle'
);

const requiredToggleLabel = computed(() =>
  props.field.required
    ? t('ACCOUNT_FORM.FIELDS.REQUIRED')
    : t('ACCOUNT_FORM.FIELDS.OPTIONAL')
);

const requiredToggleTooltip = computed(() =>
  props.field.required
    ? t('ACCOUNT_FORM.FIELD_CARD.REQUIRED_TOOLTIP')
    : t('ACCOUNT_FORM.FIELD_CARD.OPTIONAL_TOOLTIP')
);

const labelAria = computed(() =>
  t('ACCOUNT_FORM.FIELD_CARD.LABEL_ARIA', { type: typeLabel.value })
);

const onInput = val => {
  localLabel.value = val;
  emit('update-label', val);
};

const onBlur = () => {
  emit('sync');
};
</script>

<template>
  <div
    class="group flex flex-col gap-0.5 px-3 py-2 rounded-xl border transition-colors duration-150 cursor-pointer select-none"
    :class="
      isSelected
        ? 'border-woot-400 dark:border-woot-500 bg-woot-25/60 dark:bg-woot-900/20 shadow-sm'
        : 'bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700 hover:border-slate-200 dark:hover:border-slate-600 hover:shadow-sm'
    "
    @click="emit('select')"
  >
    <div class="flex items-center gap-2.5 h-8">
      <span
        class="relative shrink-0 flex items-center justify-center w-7 h-7 rounded-lg bg-slate-50 dark:bg-slate-700/50"
      >
        <fluent-icon
          :icon="typeIcon"
          size="13"
          class="text-slate-500 dark:text-slate-400 transition-opacity duration-100 group-hover:opacity-0"
          aria-hidden="true"
        />
        <span
          class="drag-handle absolute inset-0 flex items-center justify-center cursor-grab active:cursor-grabbing opacity-0 group-hover:opacity-100 transition-opacity duration-100 text-slate-400 dark:text-slate-500"
          aria-hidden="true"
        >
          <fluent-icon icon="drag" size="14" />
        </span>
      </span>

      <input
        :value="localLabel"
        type="text"
        class="reset-base flex-1 min-w-0 m-0 h-8 py-0 px-0 text-sm font-medium bg-transparent border-0 text-slate-800 dark:text-slate-100 placeholder-slate-300 dark:placeholder-slate-600 leading-none focus-visible:outline-none focus-visible:underline focus-visible:decoration-woot-400"
        :placeholder="$t('ACCOUNT_FORM.FIELD_CARD.LABEL_PLACEHOLDER')"
        :aria-label="labelAria"
        @click.stop
        @input="onInput($event.target.value)"
        @blur="onBlur"
      />

      <button
        type="button"
        v-tooltip.top="{ content: requiredToggleTooltip, delay: { show: 300, hide: 0 } }"
        class="inline-flex shrink-0 items-center gap-1 h-7 px-2 rounded-lg border text-[10px] font-medium transition-colors duration-150 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-400"
        :class="
          field.required
            ? 'bg-woot-50 text-woot-700 dark:bg-woot-900/40 dark:text-woot-300 border-woot-200 dark:border-woot-700/60 hover:bg-woot-100 dark:hover:bg-woot-900/60'
            : 'bg-slate-50 text-slate-500 dark:bg-slate-700/40 dark:text-slate-400 border-slate-200 dark:border-slate-600/60 hover:bg-slate-100 dark:hover:bg-slate-700/60 hover:text-slate-600 dark:hover:text-slate-300'
        "
        :aria-label="requiredToggleTooltip"
        @click.stop="emit('toggle-required')"
      >
        <fluent-icon
          :icon="requiredToggleIcon"
          size="12"
          aria-hidden="true"
        />
        {{ requiredToggleLabel }}
      </button>

      <span
        class="shrink-0 opacity-0 group-hover:opacity-100 transition-opacity duration-100"
        @click.stop="emit('remove')"
      >
        <FormIconButton
          icon="dismiss"
          color-scheme="alert"
          :tooltip="$t('ACCOUNT_FORM.FIELD_CARD.REMOVE')"
        />
      </span>
    </div>

    <div class="flex items-center gap-2.5 h-4">
      <span class="shrink-0 w-7" aria-hidden="true" />
      <span class="text-[10px] text-slate-400 dark:text-slate-500 leading-none truncate">
        {{ typeLabel }}
      </span>
    </div>
  </div>
</template>
