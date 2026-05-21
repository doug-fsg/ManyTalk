<script setup>
defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  featureName: {
    type: String,
    default: '',
  },
  upgradeUrl: {
    type: String,
    default: '',
  },
});

defineEmits(['close']);

const openUpgradeUrl = url => {
  if (url) {
    window.open(url, '_blank', 'noopener noreferrer');
  }
};
</script>

<template>
  <woot-modal
    :show="show" @update:show="$emit('update:show', $event)"
    :on-close="() => $emit('close')"
    size="medium"
  >
    <div class="flex flex-col items-center p-8 text-center">
      <div class="w-16 h-16 mb-4 rounded-full bg-woot-25 dark:bg-woot-900 flex items-center justify-center">
        <fluent-icon
          icon="premium"
          size="24"
          class="text-woot-500 dark:text-woot-500"
        />
      </div>
      <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-25 mb-2">
        {{ title }}
      </h2>
      <p class="text-slate-600 dark:text-slate-300 mb-6 max-w-md">
        {{ description }}
      </p>
      <div class="flex gap-3">
        <woot-button
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('GENERAL_SETTINGS.FORM.CANCEL') }}
        </woot-button>
        <woot-button
          v-if="upgradeUrl"
          color-scheme="primary"
          @click="openUpgradeUrl(upgradeUrl)"
        >
          {{ $t('BILLING.UPGRADE.UPGRADE_BUTTON') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
