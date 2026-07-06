<script setup>
import { computed } from 'vue';
import FormLogoUpload from './FormLogoUpload.vue';
import { DEFAULT_FORM_BRANDING } from 'shared/helpers/formBrandingHelpers';

const props = defineProps({
  branding: { type: Object, required: true },
  accountId: { type: [Number, String], required: true },
});

const emit = defineEmits(['update:branding']);

const local = computed(() => ({
  ...DEFAULT_FORM_BRANDING,
  ...(props.branding || {}),
}));

const hasLogo = computed(() => Boolean(local.value.logo_url));
const logoExpand = computed(
  () => local.value.logo_expand === true || local.value.logo_expand === 'true'
);

const patch = partial => {
  emit('update:branding', { ...local.value, ...partial });
};

const setColor = (key, value) => {
  if (!value) return;
  patch({ [key]: value });
};
const setLogoUrl = url => patch({ logo_url: url || '' });
const setAlignment = alignment => patch({ logo_alignment: alignment });
const setExpand = event =>
  patch({ logo_expand: Boolean(event?.target?.checked) });

const alignmentOptions = [
  { key: 'left', labelKey: 'ACCOUNT_FORM.APPEARANCE.LOGO_ALIGN_LEFT' },
  { key: 'center', labelKey: 'ACCOUNT_FORM.APPEARANCE.LOGO_ALIGN_CENTER' },
  { key: 'right', labelKey: 'ACCOUNT_FORM.APPEARANCE.LOGO_ALIGN_RIGHT' },
];

const colorFields = [
  {
    key: 'primary_color',
    labelKey: 'ACCOUNT_FORM.APPEARANCE.PRIMARY_COLOR',
    tooltipKey: 'ACCOUNT_FORM.APPEARANCE.PRIMARY_COLOR_TOOLTIP',
  },
  {
    key: 'background_color',
    labelKey: 'ACCOUNT_FORM.APPEARANCE.BACKGROUND_COLOR',
    tooltipKey: 'ACCOUNT_FORM.APPEARANCE.BACKGROUND_COLOR_TOOLTIP',
  },
  {
    key: 'page_background_color',
    labelKey: 'ACCOUNT_FORM.APPEARANCE.PAGE_BACKGROUND_COLOR',
    tooltipKey: 'ACCOUNT_FORM.APPEARANCE.PAGE_BACKGROUND_COLOR_TOOLTIP',
  },
  {
    key: 'text_color',
    labelKey: 'ACCOUNT_FORM.APPEARANCE.TEXT_COLOR',
    tooltipKey: 'ACCOUNT_FORM.APPEARANCE.TEXT_COLOR_TOOLTIP',
  },
];
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Colors -->
    <div>
      <p
        class="mb-3 text-xs font-semibold tracking-wider uppercase text-slate-400 dark:text-slate-500"
      >
        {{ $t('ACCOUNT_FORM.SETTINGS_TAB.VISUAL_IDENTITY') }}
      </p>
      <div
        class="px-4 py-3 bg-white border border-slate-100 dark:bg-slate-800 dark:border-slate-700 rounded-xl"
      >
        <div class="flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-center sm:gap-x-8 sm:gap-y-4">
          <div
            v-for="field in colorFields"
            :key="field.key"
            class="flex items-center gap-3"
          >
            <label
              class="text-sm shrink-0 text-slate-600 dark:text-slate-300"
              :title="$t(field.tooltipKey)"
            >
              {{ $t(field.labelKey) }}
            </label>
            <woot-color-picker
              :value="local[field.key]"
              @input="val => setColor(field.key, val)"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Logo -->
    <div>
      <p
        class="mb-3 text-xs font-semibold tracking-wider uppercase text-slate-400 dark:text-slate-500"
      >
        {{ $t('ACCOUNT_FORM.APPEARANCE.LOGO_SECTION') }}
      </p>
      <div
        class="bg-white border divide-y border-slate-100 dark:bg-slate-800 dark:border-slate-700 divide-slate-100 dark:divide-slate-700 rounded-xl"
      >
        <div class="flex items-center gap-3 px-4 py-3">
          <label class="text-sm shrink-0 text-slate-600 dark:text-slate-300">
            {{ $t('ACCOUNT_FORM.SETTINGS_TAB.LOGO') }}
          </label>
          <FormLogoUpload
            :value="local.logo_url"
            :account-id="accountId"
            @input="setLogoUrl"
          />
        </div>

        <div v-if="hasLogo" class="px-4 py-3">
          <label
            class="block mb-2 text-xs font-medium text-slate-500 dark:text-slate-400"
          >
            {{ $t('ACCOUNT_FORM.APPEARANCE.LOGO_ALIGNMENT') }}
          </label>
          <div
            v-if="!logoExpand"
            class="inline-flex items-center gap-0.5 p-0.5 bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg"
            role="group"
            :aria-label="$t('ACCOUNT_FORM.APPEARANCE.LOGO_ALIGNMENT')"
          >
            <button
              v-for="opt in alignmentOptions"
              :key="opt.key"
              type="button"
              class="flex items-center justify-center min-w-[36px] min-h-[36px] px-2.5 rounded-md text-xs font-medium transition-all duration-150"
              :class="
                local.logo_alignment === opt.key
                  ? 'bg-woot-500 text-white shadow-sm'
                  : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
              "
              :aria-pressed="local.logo_alignment === opt.key"
              @click="setAlignment(opt.key)"
            >
              {{ $t(opt.labelKey) }}
            </button>
          </div>
          <p v-else class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('ACCOUNT_FORM.APPEARANCE.LOGO_EXPAND_HINT') }}
          </p>
        </div>

        <div v-if="hasLogo" class="px-4 py-3">
          <label
            class="flex items-center gap-2 text-sm cursor-pointer text-slate-700 dark:text-slate-200"
          >
            <input
              type="checkbox"
              class="rounded border-slate-300 text-woot-500 focus:ring-woot-500"
              :checked="logoExpand"
              @change="setExpand"
            />
            {{ $t('ACCOUNT_FORM.APPEARANCE.LOGO_EXPAND') }}
          </label>
        </div>
      </div>
    </div>
  </div>
</template>
