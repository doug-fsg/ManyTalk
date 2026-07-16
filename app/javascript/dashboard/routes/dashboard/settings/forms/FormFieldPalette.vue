<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import FormIconButton from './FormIconButton.vue';

const props = defineProps({
  nativeFields: { type: Array, default: () => [] },
  customAttributes: { type: Array, default: () => [] },
  usedAttributeKeys: { type: Array, default: () => [] },
});

const emit = defineEmits(['add-native', 'add-custom', 'create-attribute', 'attribute-deleted']);

const { t } = useI18n();
const store = useStore();

const showDeleteModal = ref(false);
const attributeToDelete = ref(null);

const NATIVE_ICONS = { name: 'person', email: 'mail', phone_number: 'call' };

const DISPLAY_TYPE_ICONS = {
  text: 'document',
  textarea: 'text-description',
  number: 'number-symbol',
  currency: 'tag',
  percent: 'number-symbol',
  link: 'link',
  date: 'calendar',
  list: 'list',
  checkbox: 'checkmark-circle',
  file: 'attach',
};

const TYPE_I18N_KEYS = {
  text: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.TEXT',
  textarea: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.TEXTAREA',
  number: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.NUMBER',
  currency: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.CURRENCY',
  percent: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.PERCENT',
  link: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.LINK',
  date: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.DATE',
  list: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.LIST',
  checkbox: 'ATTRIBUTES_MGMT.ADD.FORM.TYPE.OPTIONS.CHECKBOX',
};

const attrIcon = attr => DISPLAY_TYPE_ICONS[attr.attribute_display_type] || 'tag';

const attrTypeLabel = attr => {
  const key = TYPE_I18N_KEYS[attr.attribute_display_type];
  return key ? t(key) : t('ACCOUNT_FORM.PALETTE.ATTRIBUTE_FALLBACK');
};

const isInForm = attr => props.usedAttributeKeys.includes(attr.attribute_key);

const hasAnyFields = computed(
  () => props.nativeFields.length > 0 || props.customAttributes.length > 0
);

const attributeDeleteName = computed(
  () => attributeToDelete.value?.attribute_display_name || ''
);

const openDelete = attr => {
  attributeToDelete.value = attr;
  showDeleteModal.value = true;
};

const closeDelete = () => {
  showDeleteModal.value = false;
  attributeToDelete.value = null;
};

const confirmDelete = async () => {
  const attr = attributeToDelete.value;
  if (!attr?.id) return;

  try {
    await store.dispatch('attributes/delete', attr.id);
    emit('attribute-deleted', attr);
    useAlert(t('ATTRIBUTES_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error?.message || t('ATTRIBUTES_MGMT.DELETE.API.ERROR_MESSAGE'));
  } finally {
    closeDelete();
  }
};
</script>

<template>
  <aside
    class="flex flex-col gap-0 h-full overflow-y-auto bg-white dark:bg-slate-900 border-r border-slate-100 dark:border-slate-800"
  >
    <div class="px-4 pt-5 pb-3 shrink-0">
      <p class="text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('ACCOUNT_FORM.PALETTE.TITLE') }}
      </p>
      <p class="mt-0.5 text-xs text-slate-400 dark:text-slate-500 leading-relaxed">
        {{ $t('ACCOUNT_FORM.PALETTE.HINT') }}
      </p>
      <button
        type="button"
        class="mt-3 flex items-center justify-center gap-1.5 w-full px-3 py-2 text-xs font-medium rounded-lg border border-dashed border-slate-200 dark:border-slate-600 text-slate-500 dark:text-slate-400 hover:border-woot-300 dark:hover:border-woot-600 hover:text-woot-600 dark:hover:text-woot-400 hover:bg-woot-25/40 dark:hover:bg-woot-900/20 transition-colors duration-150 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-400"
        @click="emit('create-attribute')"
      >
        <fluent-icon icon="add-circle" size="14" aria-hidden="true" />
        {{ $t('ATTRIBUTES_MGMT.HEADER_BTN_TXT') }}
      </button>
    </div>

    <div
      v-if="!hasAnyFields"
      class="flex flex-col items-center gap-2 py-8 px-4 text-center"
    >
      <fluent-icon
        icon="checkmark-circle"
        size="24"
        class="text-slate-300 dark:text-slate-600"
      />
      <p class="text-xs text-slate-400 dark:text-slate-500">
        {{ $t('ACCOUNT_FORM.PALETTE.ALL_ADDED') }}
      </p>
    </div>

    <div v-if="nativeFields.length" class="px-3 pb-2">
      <p
        class="px-1 pb-1.5 text-[10px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500"
      >
        {{ $t('ACCOUNT_FORM.PALETTE.NATIVE_FIELDS') }}
      </p>
      <div class="flex flex-col gap-1">
        <button
          v-for="field in nativeFields"
          :key="field.key"
          type="button"
          class="group flex items-center gap-2 w-full px-2.5 py-2 text-left rounded-xl border border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800 hover:border-woot-200 dark:hover:border-woot-700 hover:bg-woot-25/40 dark:hover:bg-woot-900/20 transition-all duration-150"
          @click="emit('add-native', field)"
        >
          <span
            class="shrink-0 flex items-center justify-center w-6 h-6 rounded-md bg-slate-50 dark:bg-slate-700 group-hover:bg-woot-50 dark:group-hover:bg-woot-900/30 transition-colors duration-150"
          >
            <fluent-icon
              :icon="NATIVE_ICONS[field.field] || 'text-description'"
              size="13"
              class="text-slate-400 dark:text-slate-500 group-hover:text-woot-500 dark:group-hover:text-woot-400 transition-colors duration-150"
              aria-hidden="true"
            />
          </span>
          <span class="text-sm text-slate-700 dark:text-slate-200 group-hover:text-woot-700 dark:group-hover:text-woot-300 transition-colors duration-150">
            {{ field.label }}
          </span>
        </button>
      </div>
    </div>

    <div
      v-if="nativeFields.length && customAttributes.length"
      class="mx-3 border-t border-slate-100 dark:border-slate-800 my-1"
    />

    <div v-if="customAttributes.length" class="px-3 pb-3">
      <p
        class="px-1 pb-1.5 text-[10px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500"
      >
        {{ $t('ACCOUNT_FORM.PALETTE.CUSTOM_ATTRIBUTES') }}
      </p>

      <div class="flex flex-col gap-1">
        <div
          v-for="attr in customAttributes"
          :key="attr.attribute_key"
          class="group flex items-center gap-1 w-full px-2.5 py-2 rounded-xl border transition-all duration-150"
          :class="
            isInForm(attr)
              ? 'border-slate-100 dark:border-slate-700 bg-slate-50/80 dark:bg-slate-800/60'
              : 'border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800 hover:border-woot-200 dark:hover:border-woot-700 hover:bg-woot-25/40 dark:hover:bg-woot-900/20'
          "
        >
          <button
            type="button"
            class="flex flex-1 items-center gap-2 min-w-0 text-left"
            :class="isInForm(attr) ? 'cursor-default' : 'cursor-pointer'"
            :disabled="isInForm(attr)"
            @click="!isInForm(attr) && emit('add-custom', attr)"
          >
            <span
              class="shrink-0 flex items-center justify-center w-6 h-6 rounded-md"
              :class="isInForm(attr) ? 'bg-slate-100 dark:bg-slate-700' : 'bg-slate-50 dark:bg-slate-700 group-hover:bg-woot-50 dark:group-hover:bg-woot-900/30'"
            >
              <fluent-icon
                :icon="attrIcon(attr)"
                size="13"
                class="transition-colors duration-150"
                :class="
                  isInForm(attr)
                    ? 'text-slate-300 dark:text-slate-600'
                    : 'text-slate-400 dark:text-slate-500 group-hover:text-woot-500 dark:group-hover:text-woot-400'
                "
                aria-hidden="true"
              />
            </span>
            <div class="flex-1 min-w-0 pr-1">
              <span
                class="block text-sm truncate transition-colors duration-150"
                :class="
                  isInForm(attr)
                    ? 'text-slate-400 dark:text-slate-500'
                    : 'text-slate-700 dark:text-slate-200 group-hover:text-woot-700 dark:group-hover:text-woot-300'
                "
              >
                {{ attr.attribute_display_name || attr.attribute_key }}
              </span>
              <span class="relative block text-[10px] leading-tight text-slate-400 dark:text-slate-500">
                <span
                  class="transition-opacity duration-150"
                  :class="isInForm(attr) ? 'group-hover:opacity-0' : ''"
                >
                  {{ attrTypeLabel(attr) }}
                </span>
                <span
                  v-if="isInForm(attr)"
                  class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-150"
                >
                  {{ $t('ACCOUNT_FORM.PALETTE.IN_FORM') }}
                </span>
              </span>
            </div>
          </button>

          <span
            class="shrink-0 opacity-0 group-hover:opacity-100 focus-within:opacity-100 transition-opacity duration-150"
            @click.stop="openDelete(attr)"
          >
            <FormIconButton
              icon="dismiss-circle"
              color-scheme="alert"
              :tooltip="$t('ATTRIBUTES_MGMT.LIST.BUTTONS.DELETE')"
            />
          </span>
        </div>
      </div>
    </div>

    <woot-confirm-delete-modal
      v-if="showDeleteModal"
      :show.sync="showDeleteModal"
      :title="
        $t('ATTRIBUTES_MGMT.DELETE.CONFIRM.TITLE', {
          attributeName: attributeDeleteName,
        })
      "
      :message="$t('ATTRIBUTES_MGMT.DELETE.CONFIRM.MESSAGE')"
      :confirm-text="`${$t('ATTRIBUTES_MGMT.DELETE.CONFIRM.YES')} ${attributeDeleteName}`"
      :reject-text="$t('ATTRIBUTES_MGMT.DELETE.CONFIRM.NO')"
      :confirm-value="attributeDeleteName"
      :confirm-place-holder-text="
        $t('ATTRIBUTES_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
          attributeName: attributeDeleteName,
        })
      "
      @on-confirm="confirmDelete"
      @on-close="closeDelete"
    />
  </aside>
</template>
