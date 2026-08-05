<script setup>
import { ref, watch, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';

const props = defineProps({
  graphSettings: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-settings']);
const store = useStore();
const { t } = useI18n();

onMounted(() => store.dispatch('labels/get'));

const selectedTabIndex = ref(0);

const tabs = computed(() => [
  { key: 'client', name: t('WORKFLOW.EDITOR.FLOW_SETTINGS_TAB_CLIENT') },
  { key: 'enrollment', name: t('WORKFLOW.EDITOR.FLOW_SETTINGS_TAB_ENROLLMENT') },
  { key: 'team', name: t('WORKFLOW.EDITOR.FLOW_SETTINGS_TAB_TEAM') },
  { key: 'reentry', name: t('WORKFLOW.EDITOR.FLOW_SETTINGS_TAB_REENTRY') },
]);

const activeTabKey = computed(() => tabs.value[selectedTabIndex.value]?.key || 'client');

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

const patchSettings = patch => {
  localSettings.value = { ...localSettings.value, ...patch };
  emit('update-settings', localSettings.value);
};

const updateSettings = (key, value) => {
  patchSettings({ [key]: value });
};

const contactReplyMode = computed(() => {
  if (localSettings.value.cancel_on_contact_reply === true) return 'cancel';
  if (localSettings.value.pause_on_contact_reply === false) return 'continue';
  return 'pause';
});

const contactReplyOptions = computed(() => [
  {
    id: 'continue',
    title: t('WORKFLOW.EDITOR.REPLY_CONTINUE'),
    description: t('WORKFLOW.EDITOR.REPLY_CONTINUE_DESC'),
  },
  {
    id: 'pause',
    title: t('WORKFLOW.EDITOR.REPLY_PAUSE'),
    description: t('WORKFLOW.EDITOR.REPLY_PAUSE_DESC'),
  },
  {
    id: 'cancel',
    title: t('WORKFLOW.EDITOR.REPLY_CANCEL'),
    description: t('WORKFLOW.EDITOR.REPLY_CANCEL_DESC'),
  },
]);

const setContactReplyMode = mode => {
  if (props.readOnly) return;
  patchSettings({
    cancel_on_contact_reply: mode === 'cancel',
    pause_on_contact_reply: mode === 'pause',
  });
};

const enrollmentScope = computed(
  () => localSettings.value.enrollment_scope || 'contact'
);

const enrollmentScopeOptions = computed(() => [
  {
    id: 'conversation',
    title: t('WORKFLOW.EDITOR.ENROLLMENT_SCOPE_CONVERSATION'),
    description: t('WORKFLOW.EDITOR.ENROLLMENT_SCOPE_CONVERSATION_DESC'),
  },
  {
    id: 'contact',
    title: t('WORKFLOW.EDITOR.ENROLLMENT_SCOPE_CONTACT'),
    description: t('WORKFLOW.EDITOR.ENROLLMENT_SCOPE_CONTACT_DESC'),
  },
]);

const setEnrollmentScope = scope => {
  if (props.readOnly) return;
  updateSettings('enrollment_scope', scope);
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
  patchSettings(patch);
};

const onTabChange = index => {
  selectedTabIndex.value = index;
};

const numberInputClass =
  'w-full text-sm border border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500/30 disabled:opacity-50';

const radioCardClass = selected =>
  selected
    ? 'border-woot-500 bg-woot-50/80 dark:bg-woot-950/30'
    : 'border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500';
</script>

<template>
  <div class="flow-settings-panel flex flex-col h-full min-h-0">
    <woot-tabs
      class="settings--tabs flow-settings-panel__tabs"
      :index="selectedTabIndex"
      :border="false"
      @change="onTabChange"
    >
      <woot-tabs-item
        v-for="tab in tabs"
        :key="tab.key"
        :name="tab.name"
        :show-badge="false"
      />
    </woot-tabs>

    <div class="flow-settings-panel__body flex-1 min-h-0 overflow-y-auto pt-4">
      <div v-if="activeTabKey === 'client'" class="space-y-4">
        <div>
          <p class="text-sm font-medium text-slate-800 dark:text-slate-100 mb-2">
            {{ $t('WORKFLOW.EDITOR.FLOW_SETTINGS_CLIENT_REPLY_TITLE') }}
          </p>
          <div class="space-y-2">
            <label
              v-for="option in contactReplyOptions"
              :key="option.id"
              class="flex gap-3 p-3 rounded-lg border cursor-pointer transition-colors"
              :class="radioCardClass(contactReplyMode === option.id)"
            >
              <input
                type="radio"
                name="contact-reply-mode"
                :value="option.id"
                :checked="contactReplyMode === option.id"
                :disabled="readOnly"
                class="mt-0.5 text-woot-500 focus:ring-woot-500/30"
                @change="setContactReplyMode(option.id)"
              />
              <span class="min-w-0">
                <span class="block text-sm font-medium text-slate-800 dark:text-slate-100">
                  {{ option.title }}
                </span>
                <span class="block text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
                  {{ option.description }}
                </span>
              </span>
            </label>
          </div>
        </div>

        <div
          class="flex items-start justify-between gap-4 py-3 border-t border-slate-75 dark:border-slate-700/50"
        >
          <div class="min-w-0 pr-2">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.EDITOR.CANCEL_ON_RESOLVED') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              {{ $t('WORKFLOW.EDITOR.CANCEL_ON_RESOLVED_DESC') }}
            </p>
          </div>
          <woot-switch
            :value="localSettings.cancel_on_conversation_resolved !== false"
            :disabled="readOnly"
            size="small"
            class="shrink-0 mt-0.5"
            @input="updateSettings('cancel_on_conversation_resolved', $event)"
          />
        </div>
      </div>

      <div v-else-if="activeTabKey === 'enrollment'" class="space-y-4">
        <div>
          <p class="text-sm font-medium text-slate-800 dark:text-slate-100 mb-2">
            {{ $t('WORKFLOW.EDITOR.FLOW_SETTINGS_ENROLLMENT_SCOPE_TITLE') }}
          </p>
          <div class="space-y-2">
            <label
              v-for="option in enrollmentScopeOptions"
              :key="option.id"
              class="flex gap-3 p-3 rounded-lg border cursor-pointer transition-colors"
              :class="radioCardClass(enrollmentScope === option.id)"
            >
              <input
                type="radio"
                name="enrollment-scope"
                :value="option.id"
                :checked="enrollmentScope === option.id"
                :disabled="readOnly"
                class="mt-0.5 text-woot-500 focus:ring-woot-500/30"
                @change="setEnrollmentScope(option.id)"
              />
              <span class="min-w-0">
                <span class="block text-sm font-medium text-slate-800 dark:text-slate-100">
                  {{ option.title }}
                </span>
                <span class="block text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
                  {{ option.description }}
                </span>
              </span>
            </label>
          </div>
        </div>

        <div
          class="flex items-start justify-between gap-4 py-3 border-t border-slate-75 dark:border-slate-700/50"
        >
          <div class="min-w-0 pr-2">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.EDITOR.ENROLL_LATEST_ONLY') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              {{ $t('WORKFLOW.EDITOR.ENROLL_LATEST_ONLY_DESC') }}
            </p>
          </div>
          <woot-switch
            :value="localSettings.enroll_latest_conversation_only !== false"
            :disabled="readOnly"
            size="small"
            class="shrink-0 mt-0.5"
            @input="updateSettings('enroll_latest_conversation_only', $event)"
          />
        </div>

        <div
          class="flex items-start justify-between gap-4 py-3 border-t border-slate-75 dark:border-slate-700/50"
        >
          <div class="min-w-0 pr-2">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.EDITOR.MANUAL_START_ONLY') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              {{ $t('WORKFLOW.EDITOR.MANUAL_START_ONLY_DESC') }}
            </p>
          </div>
          <woot-switch
            :value="localSettings.allow_manual_start_only === true"
            :disabled="readOnly"
            size="small"
            class="shrink-0 mt-0.5"
            @input="updateSettings('allow_manual_start_only', $event)"
          />
        </div>

        <div
          class="flex items-start justify-between gap-4 py-3 border-t border-slate-75 dark:border-slate-700/50"
        >
          <div class="min-w-0 pr-2">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.EDITOR.RESPECT_BUSINESS_HOURS') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              {{ $t('WORKFLOW.EDITOR.RESPECT_BUSINESS_HOURS_DESC') }}
            </p>
          </div>
          <woot-switch
            :value="localSettings.respect_business_hours !== false"
            :disabled="readOnly"
            size="small"
            class="shrink-0 mt-0.5"
            @input="updateSettings('respect_business_hours', $event)"
          />
        </div>
      </div>

      <div v-else-if="activeTabKey === 'team'" class="space-y-4">
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0 pr-2">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.EDITOR.CANCEL_ON_AGENT_REPLY') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              {{ $t('WORKFLOW.EDITOR.CANCEL_ON_AGENT_REPLY_DESC') }}
            </p>
          </div>
          <woot-switch
            :value="localSettings.cancel_on_agent_reply === true"
            :disabled="readOnly"
            size="small"
            class="shrink-0 mt-0.5"
            @input="updateSettings('cancel_on_agent_reply', $event)"
          />
        </div>

        <div
          v-if="allLabels.length > 0"
          class="pt-3 border-t border-slate-75 dark:border-slate-700/50"
        >
          <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('WORKFLOW.EDITOR.CANCEL_ON_LABELS') }}
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 mb-3 leading-relaxed">
            {{ $t('WORKFLOW.EDITOR.CANCEL_ON_LABELS_DESC') }}
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
        </div>
      </div>

      <div v-else-if="activeTabKey === 'reentry'" class="space-y-4">
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0 pr-2">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.EDITOR.REENROLLMENT_TITLE') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
              {{ $t('WORKFLOW.EDITOR.REENROLLMENT_DESC') }}
            </p>
          </div>
          <woot-switch
            :value="reenrollmentEnabled"
            :disabled="readOnly"
            size="small"
            class="shrink-0 mt-0.5"
            @input="onReenrollmentToggle"
          />
        </div>

        <transition name="slide-fade">
          <div
            v-if="reenrollmentEnabled"
            class="space-y-4 pt-3 border-t border-slate-75 dark:border-slate-700/50"
          >
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1"
                >
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_INTERVAL') }}
                </label>
                <div class="flex items-center gap-1.5">
                  <input
                    type="number"
                    min="0"
                    max="365"
                    :value="reenrollmentIntervalDays"
                    :disabled="readOnly"
                    :class="numberInputClass"
                    @input="
                      updateSettings(
                        'reenrollment_min_interval_days',
                        Math.max(0, parseInt($event.target.value) || 0)
                      )
                    "
                  />
                  <span
                    class="text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap"
                  >
                    {{ $t('WORKFLOW.EDITOR.DAYS') }}
                  </span>
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_INTERVAL_DESC') }}
                </p>
              </div>

              <div>
                <label
                  class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1"
                >
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_MAX') }}
                </label>
                <div class="flex items-center gap-1.5">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    :value="maxEnrollmentsPerContact"
                    :disabled="readOnly"
                    :class="numberInputClass"
                    @input="
                      updateSettings(
                        'max_enrollments_per_contact',
                        Math.max(0, parseInt($event.target.value) || 0)
                      )
                    "
                  />
                  <span class="text-xs text-slate-400 whitespace-nowrap">
                    {{ $t('WORKFLOW.EDITOR.REENROLLMENT_MAX_SUFFIX') }}
                  </span>
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_MAX_DESC') }}
                </p>
              </div>
            </div>

            <div
              class="flex items-start justify-between gap-4 pt-3 border-t border-slate-75 dark:border-slate-700/50"
            >
              <div class="min-w-0 pr-2">
                <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_ON_CANCEL') }}
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 leading-relaxed">
                  {{ $t('WORKFLOW.EDITOR.REENROLLMENT_ON_CANCEL_DESC') }}
                </p>
              </div>
              <woot-switch
                :value="localSettings.reenrollment_on_cancel !== false"
                :disabled="readOnly"
                size="small"
                class="shrink-0 mt-0.5"
                @input="updateSettings('reenrollment_on_cancel', $event)"
              />
            </div>
          </div>
        </transition>
      </div>
    </div>
  </div>
</template>

<style scoped>
.flow-settings-panel__tabs {
  flex-shrink: 0;
}

.flow-settings-panel__tabs :deep(.tabs--container) {
  margin-bottom: 0;
}

.slide-fade-enter-active {
  transition: all 0.2s ease-out;
}
.slide-fade-leave-active {
  transition: all 0.15s ease-in;
}
.slide-fade-enter,
.slide-fade-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
