<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import {
  HANDOFF_PRESET_KEYS,
  parseHandoffConditions,
  serializeHandoffConditions,
} from './aiAttendantHandoffPresets';

const emit = defineEmits(['update:show', 'apply', 'close']);

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  value: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const selected = ref([]);
const extra = ref('');

const labelsByKey = computed(() =>
  Object.fromEntries(
    HANDOFF_PRESET_KEYS.map(key => [
      key,
      t(`AI_ATTENDANT.FORM.HANDOFF_PRESETS.${key}`),
    ])
  )
);

const hydrate = () => {
  const parsed = parseHandoffConditions(props.value, labelsByKey.value);
  selected.value = [...parsed.selected];
  extra.value = parsed.extra;
};

watch(
  () => props.show,
  visible => {
    if (visible) hydrate();
  }
);

const toggle = key => {
  if (selected.value.includes(key)) {
    selected.value = selected.value.filter(item => item !== key);
    return;
  }
  selected.value = [...selected.value, key];
};

const handleClose = () => {
  emit('update:show', false);
  emit('close');
};

const apply = () => {
  emit(
    'apply',
    serializeHandoffConditions(selected.value, extra.value, labelsByKey.value)
  );
  handleClose();
};
</script>

<template>
  <woot-modal :show="show" :on-close="handleClose">
    <woot-modal-header
      :header-title="$t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.MODAL_TITLE')"
      :header-content="$t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.MODAL_HELP')"
    />
    <div class="flex flex-col gap-3 px-8 pb-6">
      <label
        v-for="key in HANDOFF_PRESET_KEYS"
        :key="key"
        class="flex items-start gap-2 text-sm text-slate-700 dark:text-slate-200 cursor-pointer m-0"
      >
        <input
          type="checkbox"
          class="mt-0.5"
          :checked="selected.includes(key)"
          @change="toggle(key)"
        />
        <span>{{ labelsByKey[key] }}</span>
      </label>

      <label class="m-0 mt-2">
        {{ $t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.EXTRA_LABEL') }}
        <textarea
          v-model="extra"
          rows="3"
          :placeholder="
            $t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.EXTRA_PLACEHOLDER')
          "
        />
      </label>

      <div class="flex items-center justify-end gap-2 mt-2">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click.prevent="handleClose"
        >
          {{ $t('AI_ATTENDANT.FORM.CANCEL') }}
        </woot-button>
        <woot-button @click.prevent="apply">
          {{ $t('AI_ATTENDANT.FORM.HANDOFF_CONDITIONS.APPLY') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
