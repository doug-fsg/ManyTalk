<script setup>
import { ref, watch, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';

const props = defineProps({
  graphSettings: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-settings']);
const store = useStore();

onMounted(() => store.dispatch('labels/get'));

const allLabels = computed(() => store.getters['labels/getLabels'] || []);
const cancelLabels = computed(() =>
  Array.isArray(localSettings.value.cancel_on_labels)
    ? localSettings.value.cancel_on_labels
    : []
);

const localSettings = ref({ ...props.graphSettings });
watch(
  () => props.graphSettings,
  val => {
    localSettings.value = { ...(val || {}) };
  },
  { deep: true }
);

const updateSettings = (key, value) => {
  localSettings.value = { ...localSettings.value, [key]: value };
  emit('update-settings', localSettings.value);
};

const onPauseOnReplyChange = checked => {
  const patch = { pause_on_contact_reply: checked };
  if (checked) patch.cancel_on_contact_reply = false;
  localSettings.value = { ...localSettings.value, ...patch };
  emit('update-settings', localSettings.value);
};

const toggleCancelLabel = label => {
  if (props.readOnly) return;
  const current = cancelLabels.value.slice();
  const idx = current.indexOf(label);
  if (idx === -1) {
    current.push(label);
  } else {
    current.splice(idx, 1);
  }
  updateSettings('cancel_on_labels', current);
};

const reenrollmentEnabled = computed(
  () => localSettings.value.allow_reenrollment === true
);

const reenrollmentIntervalDays = computed(() => {
  const value = localSettings.value.reenrollment_min_interval_days;
  return value === null || value === undefined ? 30 : value;
});

const maxEnrollmentsPerContact = computed(() => {
  const value = localSettings.value.max_enrollments_per_contact;
  return value === null || value === undefined ? 0 : value;
});

const onReenrollmentToggle = checked => {
  const patch = { allow_reenrollment: checked };
  if (!checked) {
    patch.reenrollment_min_interval_days = 30;
    patch.max_enrollments_per_contact = 0;
    patch.reenrollment_on_cancel = true;
  }
  localSettings.value = { ...localSettings.value, ...patch };
  emit('update-settings', localSettings.value);
};
</script>

<template>
  <div class="space-y-4">
    <p class="text-xs text-slate-500 dark:text-slate-400">
      {{ $t('WORKFLOW.EDITOR.CANCEL_SECTION') }}
    </p>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.cancel_on_contact_reply === true"
        :disabled="readOnly || localSettings.pause_on_contact_reply !== false"
        class="mt-1"
        @change="updateSettings('cancel_on_contact_reply', $event.target.checked)"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.CANCEL_ON_REPLY') }}
      </span>
    </label>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.cancel_on_conversation_resolved !== false"
        :disabled="readOnly"
        class="mt-1"
        @change="updateSettings('cancel_on_conversation_resolved', $event.target.checked)"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.CANCEL_ON_RESOLVED') }}
      </span>
    </label>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.pause_on_contact_reply !== false"
        :disabled="readOnly"
        class="mt-1"
        @change="onPauseOnReplyChange($event.target.checked)"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.PAUSE_ON_REPLY') }}
      </span>
    </label>
    <p class="text-xs text-slate-400 ml-7">
      {{ $t('WORKFLOW.EDITOR.PAUSE_ON_REPLY_HINT') }}
    </p>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.allow_manual_start_only === true"
        :disabled="readOnly"
        class="mt-1"
        @change="updateSettings('allow_manual_start_only', $event.target.checked)"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.MANUAL_START_ONLY') }}
      </span>
    </label>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.respect_business_hours !== false"
        :disabled="readOnly"
        class="mt-1"
        @change="updateSettings('respect_business_hours', $event.target.checked)"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.RESPECT_BUSINESS_HOURS') }}
      </span>
    </label>
    <p class="text-xs text-slate-400 ml-7">
      {{ $t('WORKFLOW.EDITOR.RESPECT_BUSINESS_HOURS_HINT') }}
    </p>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="(localSettings.enrollment_scope || 'contact') === 'contact'"
        :disabled="readOnly"
        class="mt-1"
        @change="updateSettings('enrollment_scope', $event.target.checked ? 'contact' : 'conversation')"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.ENROLLMENT_SCOPE_CONTACT') }}
      </span>
    </label>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.enroll_latest_conversation_only !== false"
        :disabled="readOnly"
        class="mt-1"
        @change="updateSettings('enroll_latest_conversation_only', $event.target.checked)"
      />
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('WORKFLOW.EDITOR.ENROLL_LATEST_ONLY') }}
      </span>
    </label>
    <p class="text-xs text-slate-400 ml-7">
      {{ $t('WORKFLOW.EDITOR.ENROLL_LATEST_ONLY_HINT') }}
    </p>

    <div class="border-t border-slate-100 dark:border-slate-700 pt-4 mt-2">
      <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
        {{ $t('WORKFLOW.EDITOR.AGENT_CANCEL_SECTION') }}
      </p>

      <label class="flex items-start gap-3 cursor-pointer mb-4">
        <input
          type="checkbox"
          :checked="localSettings.cancel_on_agent_reply === true"
          :disabled="readOnly"
          class="mt-1"
          @change="updateSettings('cancel_on_agent_reply', $event.target.checked)"
        />
        <div>
          <span class="text-sm text-slate-700 dark:text-slate-200">
            {{ $t('WORKFLOW.EDITOR.CANCEL_ON_AGENT_REPLY') }}
          </span>
          <p class="text-xs text-slate-400 mt-0.5">
            {{ $t('WORKFLOW.EDITOR.CANCEL_ON_AGENT_REPLY_HINT') }}
          </p>
        </div>
      </label>

      <div v-if="allLabels.length > 0">
        <p class="text-sm text-slate-700 dark:text-slate-200 mb-2">
          {{ $t('WORKFLOW.EDITOR.CANCEL_ON_LABELS') }}
        </p>
        <p class="text-xs text-slate-400 mb-3">
          {{ $t('WORKFLOW.EDITOR.CANCEL_ON_LABELS_HINT') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="label in allLabels"
            :key="label.title"
            type="button"
            :disabled="readOnly"
            class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium border transition-colors duration-150"
            :class="
              cancelLabels.includes(label.title)
                ? 'border-woot-500 bg-woot-50 dark:bg-woot-950/40 text-woot-700 dark:text-woot-200'
                : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:border-woot-300 dark:hover:border-woot-700'
            "
            @click="toggleCancelLabel(label.title)"
          >
            <span
              v-if="label.color"
              class="w-2 h-2 rounded-full shrink-0"
              :style="{ backgroundColor: label.color }"
            />
            {{ label.title }}
          </button>
        </div>
        <p
          v-if="cancelLabels.length > 0"
          class="text-xs text-woot-600 dark:text-woot-400 mt-2"
        >
          {{ $t('WORKFLOW.EDITOR.CANCEL_ON_LABELS_ACTIVE', { count: cancelLabels.length }) }}
        </p>
      </div>
    </div>

    <!-- Re-enrollment -->
    <div class="border-t border-slate-100 dark:border-slate-700 pt-4 mt-2">
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('WORKFLOW.EDITOR.REENROLLMENT_TITLE') }}
          </p>
          <span
            v-tooltip.top="$t('WORKFLOW.EDITOR.REENROLLMENT_HINT')"
            class="cursor-default"
          >
            <fluent-icon icon="info" size="13" class="text-slate-400 dark:text-slate-500" />
          </span>
        </div>
        <input
          type="checkbox"
          :checked="reenrollmentEnabled"
          :disabled="readOnly"
          @change="onReenrollmentToggle($event.target.checked)"
        />
      </div>

      <transition name="slide-fade">
        <div v-if="reenrollmentEnabled" class="space-y-4 pl-1">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <div class="flex items-center gap-1.5 mb-1">
                <label class="text-xs font-medium text-slate-600 dark:text-slate-400">
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_INTERVAL') }}
                </label>
                <span
                  v-tooltip.top="$t('WORKFLOW.EDITOR.REENROLLMENT_INTERVAL_HINT')"
                  class="cursor-default"
                >
                  <fluent-icon icon="info" size="12" class="text-slate-300 dark:text-slate-600" />
                </span>
              </div>
              <div class="flex items-center gap-1.5">
                <input
                  type="number"
                  min="0"
                  max="365"
                  :value="reenrollmentIntervalDays"
                  :disabled="readOnly"
                  class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500/30 disabled:opacity-50"
                  @input="updateSettings('reenrollment_min_interval_days', Math.max(0, parseInt($event.target.value) || 0))"
                />
                <span class="text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap">{{ $t('WORKFLOW.EDITOR.DAYS') }}</span>
              </div>
            </div>

            <div>
              <div class="flex items-center gap-1.5 mb-1">
                <label class="text-xs font-medium text-slate-600 dark:text-slate-400">
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_MAX') }}
                </label>
                <span
                  v-tooltip.top="$t('WORKFLOW.EDITOR.REENROLLMENT_MAX_HINT')"
                  class="cursor-default"
                >
                  <fluent-icon icon="info" size="12" class="text-slate-300 dark:text-slate-600" />
                </span>
              </div>
              <div class="flex items-center gap-1.5">
                <input
                  type="number"
                  min="0"
                  max="100"
                  :value="maxEnrollmentsPerContact"
                  :disabled="readOnly"
                  class="w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500/30 disabled:opacity-50"
                  @input="updateSettings('max_enrollments_per_contact', Math.max(0, parseInt($event.target.value) || 0))"
                />
                <span class="text-xs text-slate-400 whitespace-nowrap">{{ $t('WORKFLOW.EDITOR.REENROLLMENT_MAX_SUFFIX') }}</span>
              </div>
            </div>
          </div>

          <label class="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              :checked="localSettings.reenrollment_on_cancel !== false"
              :disabled="readOnly"
              @change="updateSettings('reenrollment_on_cancel', $event.target.checked)"
            />
            <div class="flex items-center gap-1.5">
              <span class="text-sm text-slate-700 dark:text-slate-200">
                {{ $t('WORKFLOW.EDITOR.REENROLLMENT_ON_CANCEL') }}
              </span>
              <span
                v-tooltip.top="$t('WORKFLOW.EDITOR.REENROLLMENT_ON_CANCEL_HINT')"
                class="cursor-default"
              >
                <fluent-icon icon="info" size="12" class="text-slate-300 dark:text-slate-600" />
              </span>
            </div>
          </label>
        </div>
      </transition>
    </div>
  </div>
</template>

<style scoped>
.slide-fade-enter-active { transition: all 0.2s ease-out; }
.slide-fade-leave-active { transition: all 0.15s ease-in; }
.slide-fade-enter, .slide-fade-leave-to { opacity: 0; transform: translateY(-6px); }
</style>
