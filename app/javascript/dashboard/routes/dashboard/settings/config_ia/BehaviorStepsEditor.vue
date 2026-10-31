<script setup>
import { ref, watch } from 'vue';
import draggable from 'vuedraggable';
import AiAttendantVariableField from './AiAttendantVariableField.vue';

const props = defineProps({
  initialSteps: { type: Array, default: () => [] },
  mode: { type: String, default: 'guide' },
});

const emit = defineEmits(['update:mode']);

const localSteps = ref([]);
let stepIdCounter = 0;

const makeId = () => {
  stepIdCounter += 1;
  return `step-${stepIdCounter}`;
};

const toPayload = steps =>
  (steps || []).map(step => ({
    instruction: (step.instruction || '').trim(),
    completion_criterion: (step.completion_criterion || '').trim(),
  }));

const stepsFingerprint = steps => JSON.stringify(toPayload(steps));

const hydrateFromInitial = steps => {
  const mapped = (steps || []).map(item => {
    if (typeof item === 'string') {
      return {
        id: makeId(),
        instruction: item,
        completion_criterion: '',
      };
    }
    return {
      id: makeId(),
      instruction: item.instruction || '',
      completion_criterion: item.completion_criterion || '',
    };
  });

  if (!mapped.length) {
    localSteps.value = [{ id: makeId(), instruction: '', completion_criterion: '' }];
    return;
  }

  localSteps.value = mapped;
};

watch(
  () => props.initialSteps,
  (value, oldValue) => {
    if (oldValue !== undefined && stepsFingerprint(value) === stepsFingerprint(oldValue)) {
      return;
    }
    hydrateFromInitial(value);
  },
  { immediate: true }
);

const getStepsForSave = () =>
  toPayload(localSteps.value).filter(step => step.instruction.length > 0);

defineExpose({
  getStepsForSave,
  getLocalSteps: () => localSteps.value,
});

const canAddStep = () => localSteps.value.length < 20;

const addStep = () => {
  if (!canAddStep()) return;
  localSteps.value.push({
    id: makeId(),
    instruction: '',
    completion_criterion: '',
  });
};

const removeStep = index => {
  if (localSteps.value.length <= 1) return;
  localSteps.value.splice(index, 1);
};

const onModeChange = event => {
  emit('update:mode', event.target.value);
};
</script>

<template>
  <div class="flex flex-col gap-4 w-full">
    <div class="flex flex-wrap items-end gap-2">
      <label class="behavior-steps-mode mb-0 w-36 max-w-full">
        {{ $t('AI_ATTENDANT.FORM.STEPS.MODE_LABEL') }}
        <select :value="mode" class="mb-0" @change="onModeChange">
          <option value="guide">
            {{ $t('AI_ATTENDANT.FORM.STEPS.MODE_GUIDE') }}
          </option>
          <option value="strict">
            {{ $t('AI_ATTENDANT.FORM.STEPS.MODE_STRICT') }}
          </option>
        </select>
      </label>
      <woot-button
        type="button"
        size="small"
        color-scheme="primary"
        icon="add"
        class="mb-0"
        :disabled="!canAddStep()"
        @click.prevent="addStep"
      >
        {{ $t('AI_ATTENDANT.FORM.STEPS.ADD') }}
      </woot-button>
    </div>

    <p
      class="text-xs text-slate-600 dark:text-slate-400 m-0 px-1 leading-5"
      role="note"
    >
      {{
        mode === 'strict'
          ? $t('AI_ATTENDANT.FORM.STEPS.MODE_STRICT_HELP')
          : $t('AI_ATTENDANT.FORM.STEPS.MODE_GUIDE_HELP')
      }}
    </p>

    <draggable
      v-model="localSteps"
      handle=".behavior-step-drag"
      tag="div"
      class="grid grid-cols-1 lg:grid-cols-2 gap-4"
      ghost-class="opacity-50"
      animation="160"
    >
      <div
        v-for="(step, index) in localSteps"
        :key="step.id"
        class="flex flex-col rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 p-4 shadow-sm"
      >
        <div class="flex items-center justify-between gap-2 mb-3 shrink-0">
          <div class="flex items-center gap-2 min-w-0">
            <button
              type="button"
              class="behavior-step-drag p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-grab shrink-0"
              :aria-label="$t('AI_ATTENDANT.FORM.STEPS.DRAG')"
            >
              <fluent-icon icon="drag" size="16" />
            </button>
            <span
              class="text-sm font-medium text-slate-800 dark:text-slate-100 truncate"
            >
              {{ $t('AI_ATTENDANT.FORM.STEPS.STEP_TITLE', { n: index + 1 }) }}
            </span>
          </div>
          <woot-button
            type="button"
            variant="clear"
            color-scheme="alert"
            size="tiny"
            :disabled="localSteps.length <= 1"
            @click.prevent="removeStep(index)"
          >
            {{ $t('AI_ATTENDANT.FORM.STEPS.REMOVE') }}
          </woot-button>
        </div>

        <label class="block mb-2 flex-1">
          {{ $t('AI_ATTENDANT.FORM.STEPS.INSTRUCTION') }}
          <AiAttendantVariableField
            :id="`ia-field-step-${index}-instruction`"
            v-model="step.instruction"
            :rows="3"
            :placeholder="$t('AI_ATTENDANT.FORM.STEPS.INSTRUCTION_PLACEHOLDER')"
          />
        </label>

        <label class="block mb-0">
          {{ $t('AI_ATTENDANT.FORM.STEPS.COMPLETION') }}
          <AiAttendantVariableField
            :id="`ia-field-step-${index}-completion`"
            v-model="step.completion_criterion"
            :rows="2"
            input-class="!mb-0"
            :placeholder="$t('AI_ATTENDANT.FORM.STEPS.COMPLETION_PLACEHOLDER')"
          />
        </label>
      </div>
    </draggable>
  </div>
</template>

<style scoped lang="scss">
.behavior-steps-mode select {
  height: 2rem;
  min-height: 2rem;
  padding-top: 0.25rem;
  padding-bottom: 0.25rem;
  font-size: 0.875rem;
}
</style>
