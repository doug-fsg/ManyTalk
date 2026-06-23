<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import WorkflowsAPI from 'dashboard/api/workflows';

const props = defineProps({
  show: { type: Boolean, default: false },
  workflowId: { type: [Number, String], required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const isRunning = ref(false);
const trace = ref([]);
const truncated = ref(false);
const error = ref(null);
const ran = ref(false);
const pausedAt = ref(null);
const completed = ref(false);
const decisions = ref([]);
const autoSkipWaits = ref(false);

const NODE_ICONS = {
  trigger: 'flash-on',
  action: 'play-circle',
  wait: 'clock',
  wait_for_reply: 'arrow-reply',
  condition: 'chevron-right',
  ai_outreach: 'bot',
  ai_conversation_analysis: 'document',
};

const CHOICE_META = {
  skip: { icon: 'arrow-right', labelKey: 'WORKFLOW.SIMULATE.CHOICE_SKIP' },
  replied: { icon: 'arrow-reply', labelKey: 'WORKFLOW.SIMULATE.CHOICE_REPLIED' },
  timeout: { icon: 'clock', labelKey: 'WORKFLOW.SIMULATE.CHOICE_TIMEOUT' },
  true: { icon: 'checkmark', labelKey: 'WORKFLOW.SIMULATE.CHOICE_TRUE' },
  false: { icon: 'dismiss', labelKey: 'WORKFLOW.SIMULATE.CHOICE_FALSE' },
};

const iconFor = type => NODE_ICONS[type] || 'info';

const dotClass = step => {
  if (step.pending) return 'bg-amber-400 ring-2 ring-amber-200 dark:ring-amber-800';
  if (step.simulated_branch) return 'bg-woot-500';
  if (step.type === 'condition') return 'bg-woot-500';
  if (step.type === 'trigger') return 'bg-slate-300 dark:bg-slate-600';
  return 'bg-green-500';
};

const branchLabelKey = branch => {
  const meta = CHOICE_META[branch];
  return meta ? meta.labelKey : null;
};

const simulatedBranchClass = branch => {
  if (branch === 'true' || branch === 'replied' || branch === 'skip') {
    return 'text-green-600 dark:text-green-400';
  }
  return 'text-slate-500 dark:text-slate-400';
};

const isPausedStep = step =>
  pausedAt.value && pausedAt.value.node_id === step.node_id;

const choiceMeta = branch => CHOICE_META[branch] || { icon: 'info', labelKey: null };

const statusLabel = step => {
  if (step.pending) return t('WORKFLOW.SIMULATE.PENDING_CHOICE');
  if (step.simulated_branch && branchLabelKey(step.simulated_branch)) {
    return t(branchLabelKey(step.simulated_branch));
  }
  return step.description || '';
};

const run = async () => {
  isRunning.value = true;
  error.value = null;

  try {
    const res = await WorkflowsAPI.dryRun(props.workflowId, {
      decisions: decisions.value,
      autoSkipWaits: autoSkipWaits.value,
    });
    const data = res.data || {};
    trace.value = data.trace || [];
    truncated.value = !!data.truncated;
    pausedAt.value = data.paused_at || null;
    completed.value = !!data.completed;
    if (data.error === 'no_trigger') {
      error.value = t('WORKFLOW.SIMULATE.NO_TRIGGER');
    }
  } catch {
    error.value = t('WORKFLOW.SIMULATE.RUN_ERROR');
  } finally {
    isRunning.value = false;
    ran.value = true;
  }
};

const choose = branch => {
  if (!pausedAt.value) return;
  const nodeId = pausedAt.value.node_id;
  decisions.value = [
    ...decisions.value.filter(d => d.node_id !== nodeId),
    { node_id: nodeId, branch },
  ];
  run();
};

const resetSimulation = () => {
  decisions.value = [];
  pausedAt.value = null;
  completed.value = false;
  trace.value = [];
  truncated.value = false;
  error.value = null;
  ran.value = false;
};

const close = () => {
  resetSimulation();
  emit('close');
};

const resetAndRun = () => {
  resetSimulation();
  run();
};

watch(
  () => props.show,
  visible => {
    if (visible) resetSimulation();
  }
);

watch(autoSkipWaits, () => {
  if (ran.value) run();
});

const totalActions = computed(
  () => trace.value.filter(s => s.type === 'action').length
);
const totalWaits = computed(
  () => trace.value.filter(s => ['wait', 'wait_for_reply'].includes(s.type)).length
);
</script>

<template>
  <woot-modal :show="show" :on-close="close" :close-on-backdrop-click="true">
    <div class="flex flex-col h-auto overflow-auto w-full overscroll-contain">
      <woot-modal-header
        :header-title="$t('WORKFLOW.SIMULATE.TITLE')"
        :header-content="$t('WORKFLOW.SIMULATE.SUBTITLE')"
      />

      <div class="flex flex-col px-8 pb-4">
        <div
          v-if="ran && !error"
          class="flex flex-wrap items-center gap-x-4 gap-y-2 mb-4 text-xs text-slate-500 dark:text-slate-400"
        >
          <span class="inline-flex items-center gap-1">
            <fluent-icon icon="play-circle" size="13" class="text-green-500" />
            {{ totalActions }} {{ $t('WORKFLOW.SIMULATE.STAT_ACTIONS') }}
          </span>
          <span class="inline-flex items-center gap-1">
            <fluent-icon icon="clock" size="13" class="text-amber-500" />
            {{ totalWaits }} {{ $t('WORKFLOW.SIMULATE.STAT_WAITS') }}
          </span>
          <label
            v-tooltip.top="$t('WORKFLOW.SIMULATE.AUTO_SKIP_HINT')"
            class="inline-flex items-center gap-1.5 cursor-pointer"
          >
            <input
              v-model="autoSkipWaits"
              type="checkbox"
              class="rounded border-slate-300 dark:border-slate-600"
            />
            <fluent-icon icon="arrow-right" size="13" class="text-slate-400" />
          </label>
        </div>

        <div
          v-if="error"
          class="flex items-center gap-2 rounded-lg border border-solid border-red-200 dark:border-red-800/40 bg-red-50 dark:bg-red-950/20 px-3 py-2 text-xs text-red-700 dark:text-red-300 mb-4"
        >
          <fluent-icon icon="dismiss-circle" size="14" class="shrink-0" />
          {{ error }}
        </div>

        <div
          v-else-if="!ran"
          class="flex flex-col items-center justify-center py-8 text-center"
        >
          <fluent-icon
            icon="play-circle"
            size="28"
            class="text-slate-200 dark:text-slate-700 mb-2"
          />
          <p class="text-sm text-slate-500 dark:text-slate-400">
            {{ $t('WORKFLOW.SIMULATE.EMPTY') }}
          </p>
        </div>

        <div
          v-else-if="trace.length > 0"
          class="border-t border-slate-75 dark:border-slate-700 pt-4 max-h-80 overflow-y-auto"
        >
          <ol class="space-y-0">
            <li
              v-for="(step, index) in trace"
              :key="`${step.node_id}-${index}`"
              class="relative flex gap-3 pb-3 last:pb-0"
              :class="{
                'rounded-lg border border-solid border-amber-200 dark:border-amber-800/50 bg-slate-25 dark:bg-slate-800/80 px-2 py-2 -mx-1':
                  isPausedStep(step),
              }"
            >
              <div class="flex flex-col items-center shrink-0">
                <span
                  class="w-2 h-2 rounded-full mt-1 shrink-0"
                  :class="dotClass(step)"
                />
                <span
                  v-if="index < trace.length - 1"
                  class="w-px flex-1 min-h-[1rem] bg-slate-75 dark:bg-slate-600 mt-0.5"
                />
              </div>

              <div class="flex-1 min-w-0 -mt-0.5">
                <div class="flex items-center gap-1.5 flex-wrap">
                  <fluent-icon
                    :icon="iconFor(step.type)"
                    size="13"
                    class="text-slate-500 dark:text-slate-400 shrink-0"
                    aria-hidden="true"
                  />
                  <p class="text-sm text-slate-800 dark:text-slate-100 truncate">
                    {{ step.label }}
                  </p>
                </div>

                <p
                  class="text-xs tabular-nums mt-0.5"
                  :class="simulatedBranchClass(step.simulated_branch)"
                >
                  {{ statusLabel(step) }}
                </p>

                <div
                  v-if="isPausedStep(step) && pausedAt"
                  class="flex items-center gap-1 mt-2"
                >
                  <woot-button
                    v-for="choice in pausedAt.choices"
                    :key="choice.branch"
                    v-tooltip.top="
                      choiceMeta(choice.branch).labelKey
                        ? $t(choiceMeta(choice.branch).labelKey)
                        : choice.branch
                    "
                    variant="clear"
                    color-scheme="secondary"
                    size="small"
                    :icon="choiceMeta(choice.branch).icon"
                    :disabled="isRunning"
                    :aria-label="
                      choiceMeta(choice.branch).labelKey
                        ? $t(choiceMeta(choice.branch).labelKey)
                        : choice.branch
                    "
                    @click="choose(choice.branch)"
                  />
                </div>
              </div>
            </li>
          </ol>

          <div
            v-if="completed && !pausedAt"
            class="flex items-center gap-1.5 mt-3 pt-3 border-t border-slate-75 dark:border-slate-700 text-xs text-green-600 dark:text-green-400"
          >
            <fluent-icon icon="checkmark-circle" size="14" />
            {{ $t('WORKFLOW.SIMULATE.COMPLETED') }}
          </div>

          <div
            v-if="truncated"
            class="flex items-center gap-2 mt-2 text-xs text-slate-400 dark:text-slate-500"
          >
            <fluent-icon icon="more-horizontal" size="13" />
            {{ $t('WORKFLOW.SIMULATE.TRUNCATED') }}
          </div>
        </div>

        <div
          v-else-if="ran"
          class="py-6 text-center text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('WORKFLOW.SIMULATE.NO_NODES') }}
        </div>
      </div>

      <div
        class="flex flex-row justify-end gap-2 py-4 px-6 w-full border-t border-solid border-slate-75 dark:border-slate-700"
      >
        <woot-button variant="clear" color-scheme="secondary" @click="close">
          {{ $t('WORKFLOW.SIMULATE.CLOSE') }}
        </woot-button>
        <woot-button
          v-if="ran"
          v-tooltip.top="$t('WORKFLOW.SIMULATE.RESET')"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-clockwise"
          :aria-label="$t('WORKFLOW.SIMULATE.RESET')"
          @click="resetAndRun"
        />
        <woot-button
          color-scheme="primary"
          :is-loading="isRunning"
          icon="play-circle"
          @click="run"
        >
          {{ $t('WORKFLOW.SIMULATE.RUN') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
