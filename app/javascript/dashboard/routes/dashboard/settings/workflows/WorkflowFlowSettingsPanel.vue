<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
  graphSettings: { type: Object, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['update-settings']);

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
</script>

<template>
  <div class="space-y-4">
    <p class="text-xs text-slate-500 dark:text-slate-400">
      {{ $t('WORKFLOW.EDITOR.CANCEL_SECTION') }}
    </p>

    <label class="flex items-start gap-3 cursor-pointer">
      <input
        type="checkbox"
        :checked="localSettings.cancel_on_contact_reply !== false"
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
  </div>
</template>
