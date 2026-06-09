<script setup>
import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { AI_ANALYSIS_TYPES } from './constants';

const store = useStore();

const props = defineProps({
  nodeProps: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-node']);

const whatsappInboxes = computed(() => {
  const inboxes = store.getters['inboxes/getInboxes'] || [];
  return inboxes.filter(i => i.channel_type === 'Channel::Whatsapp');
});

const selectedType = computed(
  () => (props.nodeProps.analysis_types && props.nodeProps.analysis_types[0]) || 'full_analysis'
);
const outputDestination = computed(() => props.nodeProps.output_destination || 'private_note');

const inputClass =
  'w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500/30 disabled:opacity-50';
const labelClass =
  'block text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider mb-1.5';

const analysisOptions = [
  { key: 'full_analysis', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_FULL' },
  ...AI_ANALYSIS_TYPES,
];

function update(key, value) {
  emit('update-node', { [key]: value });
}
</script>

<template>
  <div class="space-y-5">
    <!-- Tipo de análise (single select) -->
    <div>
      <label :class="labelClass">
        {{ $t('WORKFLOW.EDITOR.AI_ANALYSIS_TYPES_LABEL') }}
      </label>
      <select
        :value="selectedType"
        :disabled="readOnly"
        :class="inputClass"
        @change="update('analysis_types', [$event.target.value])"
      >
        <option
          v-for="opt in analysisOptions"
          :key="opt.key"
          :value="opt.key"
        >
          {{ $t(opt.labelKey) }}
        </option>
      </select>
    </div>

    <!-- Destino -->
    <div>
      <label :class="labelClass">
        {{ $t('WORKFLOW.EDITOR.AI_ANALYSIS_DESTINATION_LABEL') }}
      </label>
      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="opt in [
            { key: 'private_note', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_DEST_NOTE' },
            { key: 'whatsapp_external', labelKey: 'WORKFLOW.EDITOR.AI_ANALYSIS_DEST_WHATSAPP' },
          ]"
          :key="opt.key"
          type="button"
          :disabled="readOnly"
          class="rounded-lg border border-solid px-3 py-2 text-sm transition-colors disabled:opacity-50"
          :class="
            outputDestination === opt.key
              ? 'border-violet-400 bg-violet-50 font-semibold text-violet-700 dark:border-violet-600 dark:bg-violet-900/30 dark:text-violet-300'
              : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700'
          "
          @click="update('output_destination', opt.key)"
        >
          {{ $t(opt.labelKey) }}
        </button>
      </div>
    </div>

    <!-- WhatsApp externo: inbox + telefone -->
    <template v-if="outputDestination === 'whatsapp_external'">
      <div>
        <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WHATSAPP_INBOX_LABEL') }}</label>
        <div v-if="!whatsappInboxes.length" class="text-xs text-amber-600 dark:text-amber-400">
          {{ $t('WORKFLOW.EDITOR.WHATSAPP_NO_INBOX') }}
        </div>
        <select
          v-else
          :value="nodeProps.whatsapp_inbox_id || ''"
          :disabled="readOnly"
          :class="inputClass"
          @change="update('whatsapp_inbox_id', $event.target.value)"
        >
          <option value="">{{ $t('WORKFLOW.EDITOR.WHATSAPP_SELECT_INBOX') }}</option>
          <option
            v-for="inbox in whatsappInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>
      </div>
      <div>
        <label :class="labelClass">{{ $t('WORKFLOW.EDITOR.WHATSAPP_PHONE_LABEL') }}</label>
        <input
          type="tel"
          :value="nodeProps.whatsapp_phone || ''"
          :disabled="readOnly"
          :class="inputClass"
          :placeholder="$t('WORKFLOW.EDITOR.WHATSAPP_PHONE_PLACEHOLDER')"
          @input="update('whatsapp_phone', $event.target.value)"
        />
      </div>
    </template>

    <!-- Dica -->
    <p class="rounded-lg bg-slate-50 p-3 text-xs leading-relaxed text-slate-500 dark:bg-slate-800/60 dark:text-slate-400">
      {{ $t('WORKFLOW.EDITOR.AI_ANALYSIS_HINT') }}
    </p>
  </div>
</template>
