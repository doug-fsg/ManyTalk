<script setup>
import { computed, ref, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';
import KanbanStageSelect from '../macros/components/KanbanStageSelect.vue';

const TIME_ZONES = [
  'America/Sao_Paulo',
  'America/Manaus',
  'America/Rio_Branco',
  'America/Noronha',
  'UTC',
];

const props = defineProps({
  show: { type: Boolean, default: false },
  schedule: { type: Object, default: null },
  preset: { type: Object, default: () => ({}) },
  lockAudience: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'save']);
const store = useStore();
const { t } = useI18n();

const name = ref('');
const workflowId = ref('');
const weekday = ref(3);
const cadence = ref('weekly');
const onceDate = ref('');
const timeValue = ref('09:00');
const timeZone = ref('America/Sao_Paulo');
const active = ref(false);
const kanbanValue = ref([]);
const audienceCount = ref(null);
const isCounting = ref(false);
const isSaving = ref(false);
const formKey = ref(0);
let countTimer = null;

const isEdit = computed(() => Boolean(props.schedule?.id));
const recurring = computed(() => cadence.value === 'weekly');
const workflows = computed(() => store.getters['workflows/getWorkflows'] || []);
const weekdays = computed(() =>
  [0, 1, 2, 3, 4, 5, 6].map(day => ({
    id: day,
    label: t(`WORKFLOW.SCHEDULES.WEEKDAYS.${day}`),
  }))
);

const selectedPipelineId = computed(() => {
  const item = kanbanValue.value?.[0];
  return item?.id || item || null;
});

const selectedStageId = computed(() => {
  const item = kanbanValue.value?.[1];
  return item?.id || item?.name || item || null;
});

const canSubmit = computed(
  () =>
    name.value.trim() &&
    workflowId.value &&
    selectedPipelineId.value &&
    selectedStageId.value &&
    timeValue.value &&
    (recurring.value || onceDate.value)
);

const resetFromProps = () => {
  const source = props.schedule || {};
  const preset = props.preset || {};
  name.value = source.name || '';
  workflowId.value = source.workflow_id || '';
  weekday.value = source.weekday ?? 3;
  cadence.value = source.recurring === false ? 'once' : 'weekly';
  timeZone.value = source.time_zone || 'America/Sao_Paulo';
  active.value = Boolean(source.active);
  const hour = source.hour ?? 9;
  const minute = source.minute ?? 0;
  timeValue.value = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  if (source.next_run_at) {
    const local = new Date(source.next_run_at);
    const month = String(local.getMonth() + 1).padStart(2, '0');
    const day = String(local.getDate()).padStart(2, '0');
    onceDate.value = `${local.getFullYear()}-${month}-${day}`;
  } else {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const month = String(tomorrow.getMonth() + 1).padStart(2, '0');
    const day = String(tomorrow.getDate()).padStart(2, '0');
    onceDate.value = `${tomorrow.getFullYear()}-${month}-${day}`;
  }

  if (source.pipeline_id && source.stage_id) {
    kanbanValue.value = [source.pipeline_id, source.stage_id];
  } else if (preset.pipelineId && preset.stageId) {
    kanbanValue.value = [preset.pipelineId, preset.stageId];
    if (preset.stageTitle) {
      name.value =
        name.value ||
        t('WORKFLOW.SCHEDULES.PRESET_NAME', { stage: preset.stageTitle });
    }
  } else {
    kanbanValue.value = [];
  }
  audienceCount.value = null;
};

watch(
  () => props.show,
  visible => {
    if (!visible) return;
    resetFromProps();
    formKey.value += 1;
    isSaving.value = false;
  }
);

watch([selectedPipelineId, selectedStageId], ([pipelineId, stageId]) => {
  clearTimeout(countTimer);
  if (!pipelineId || !stageId) {
    audienceCount.value = null;
    return;
  }
  countTimer = setTimeout(async () => {
    isCounting.value = true;
    try {
      audienceCount.value = await store.dispatch(
        'workflowSchedules/audienceCount',
        { pipelineId, stageId }
      );
    } catch {
      audienceCount.value = null;
    } finally {
      isCounting.value = false;
    }
  }, 300);
});

const close = () => emit('close');

const save = async () => {
  if (!canSubmit.value || isSaving.value) return;
  const [hours, minutes] = timeValue.value.split(':').map(Number);
  isSaving.value = true;
  try {
    const payload = {
      id: props.schedule?.id,
      name: name.value.trim(),
      workflow_id: Number(workflowId.value),
      pipeline_id: Number(selectedPipelineId.value),
      stage_id: String(selectedStageId.value),
      hour: hours,
      minute: minutes,
      time_zone: timeZone.value,
      active: active.value,
      recurring: recurring.value,
    };
    if (recurring.value) {
      payload.weekday = Number(weekday.value);
    } else {
      payload.weekday = null;
      payload.next_run_at = new Date(
        `${onceDate.value}T${timeValue.value}:00`
      ).toISOString();
    }
    await emit('save', payload);
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <woot-modal :show="show" :on-close="close">
    <woot-modal-header
      :header-title="
        isEdit
          ? $t('WORKFLOW.SCHEDULES.EDIT_TITLE')
          : $t('WORKFLOW.SCHEDULES.ADD_TITLE')
      "
      :header-content="$t('WORKFLOW.SCHEDULES.FORM_DESC')"
    />
    <form class="flex flex-col w-full px-8 pb-8" @submit.prevent="save">
      <woot-input
        v-model="name"
        :label="$t('WORKFLOW.SCHEDULES.NAME_LABEL')"
        type="text"
        :placeholder="$t('WORKFLOW.SCHEDULES.NAME_PLACEHOLDER')"
      />

      <label class="mt-4 text-sm font-medium text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.SCHEDULES.WORKFLOW_LABEL') }}
        <select
          v-model="workflowId"
          class="mt-1 block w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
        >
          <option value="">{{ $t('WORKFLOW.SCHEDULES.WORKFLOW_PLACEHOLDER') }}</option>
          <option
            v-for="workflow in workflows"
            :key="workflow.id"
            :value="workflow.id"
          >
            {{ workflow.name }}
            {{ workflow.active ? '' : $t('WORKFLOW.SCHEDULES.INACTIVE_SUFFIX') }}
          </option>
        </select>
      </label>
      <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('WORKFLOW.SCHEDULES.WORKFLOW_HINT') }}
      </p>

      <div class="mt-4">
        <p class="mb-2 text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('WORKFLOW.SCHEDULES.AUDIENCE_LABEL') }}
        </p>
        <p
          v-if="lockAudience"
          class="text-sm text-slate-600 dark:text-slate-300"
        >
          {{ preset.stageTitle || selectedStageId }}
        </p>
        <KanbanStageSelect v-else :key="formKey" v-model="kanbanValue" />
        <p
          v-if="isCounting"
          class="mt-2 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('WORKFLOW.SCHEDULES.AUDIENCE_LOADING') }}
        </p>
        <p
          v-else-if="audienceCount !== null"
          class="mt-2 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('WORKFLOW.SCHEDULES.AUDIENCE_COUNT', { count: audienceCount }) }}
        </p>
      </div>

      <fieldset class="mt-4">
        <legend class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('WORKFLOW.SCHEDULES.CADENCE_LABEL') }}
        </legend>
        <div class="mt-2 flex flex-wrap gap-3">
          <label class="inline-flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200">
            <input v-model="cadence" type="radio" value="weekly" />
            {{ $t('WORKFLOW.SCHEDULES.CADENCE_WEEKLY') }}
          </label>
          <label class="inline-flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200">
            <input v-model="cadence" type="radio" value="once" />
            {{ $t('WORKFLOW.SCHEDULES.CADENCE_ONCE') }}
          </label>
        </div>
      </fieldset>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-4">
        <label
          v-if="recurring"
          class="text-sm font-medium text-slate-700 dark:text-slate-200"
        >
          {{ $t('WORKFLOW.SCHEDULES.WEEKDAY_LABEL') }}
          <select
            v-model.number="weekday"
            class="mt-1 block w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          >
            <option v-for="day in weekdays" :key="day.id" :value="day.id">
              {{ day.label }}
            </option>
          </select>
        </label>
        <label
          v-else
          class="text-sm font-medium text-slate-700 dark:text-slate-200"
        >
          {{ $t('WORKFLOW.SCHEDULES.ONCE_DATE_LABEL') }}
          <input
            v-model="onceDate"
            type="date"
            class="mt-1 block w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          />
        </label>
        <label class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('WORKFLOW.SCHEDULES.TIME_LABEL') }}
          <input
            v-model="timeValue"
            type="time"
            class="mt-1 block w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
          />
        </label>
      </div>

      <label class="mt-4 text-sm font-medium text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.SCHEDULES.TIMEZONE_LABEL') }}
        <select
          v-model="timeZone"
          class="mt-1 block w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm"
        >
          <option v-for="zone in TIME_ZONES" :key="zone" :value="zone">
            {{ zone }}
          </option>
        </select>
      </label>

      <label
        class="mt-4 inline-flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
      >
        <input v-model="active" type="checkbox" />
        {{ $t('WORKFLOW.SCHEDULES.ACTIVE_LABEL') }}
      </label>
      <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('WORKFLOW.SCHEDULES.ACTIVE_HINT') }}
      </p>

      <div class="flex justify-end gap-2 mt-6">
        <woot-button variant="clear" @click.prevent="close">
          {{ $t('WORKFLOW.SCHEDULES.CANCEL') }}
        </woot-button>
        <woot-button
          :is-disabled="!canSubmit"
          :is-loading="isSaving"
          native-type="submit"
        >
          {{ $t('WORKFLOW.SCHEDULES.SAVE') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>
