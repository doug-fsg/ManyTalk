<script setup>
import { computed, onBeforeUnmount, onMounted, shallowRef } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';

const props = defineProps({
  columns: {
    type: Array,
    default: () => [],
  },
  /** Array of currently visible optional column keys */
  visibleKeys: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['toggle']);

const { t } = useI18n();
const isOpen = shallowRef(false);
const rootEl = shallowRef(null);

const standardColumns = computed(() =>
  props.columns.filter(col => col.kind !== 'custom')
);

const attributeColumns = computed(() =>
  props.columns.filter(col => col.kind === 'custom')
);

const isChecked = key => props.visibleKeys.includes(key);

const columnLabel = col => {
  if (col.label) return col.label;
  return t(`CONTACTS_PAGE.LIST.TABLE_HEADER.${col.i18nKey}`);
};

const toggleOpen = () => {
  isOpen.value = !isOpen.value;
};

const close = () => {
  isOpen.value = false;
};

const onToggle = key => {
  emit('toggle', key);
};

const onDocumentPointerDown = event => {
  if (!isOpen.value || !rootEl.value) return;
  if (!rootEl.value.contains(event.target)) {
    close();
  }
};

const onDocumentKeydown = event => {
  if (event.key === 'Escape' && isOpen.value) {
    close();
  }
};

onMounted(() => {
  document.addEventListener('pointerdown', onDocumentPointerDown);
  document.addEventListener('keydown', onDocumentKeydown);
});

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', onDocumentPointerDown);
  document.removeEventListener('keydown', onDocumentKeydown);
});
</script>

<template>
  <div ref="rootEl" class="relative shrink-0">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 h-8 px-2.5 rounded-lg text-sm font-medium
        text-slate-700 dark:text-slate-200
        hover:bg-slate-50 dark:hover:bg-slate-800
        focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-woot-500 focus-visible:ring-offset-1
        dark:focus-visible:ring-offset-slate-900
        transition-colors duration-150"
      :aria-expanded="isOpen ? 'true' : 'false'"
      aria-haspopup="dialog"
      :aria-label="$t('CONTACTS_PAGE.COLUMNS.TRIGGER_ARIA')"
      @click="toggleOpen"
    >
      <FluentIcon
        icon="table-switch"
        size="16"
        class="text-slate-500 dark:text-slate-400"
        aria-hidden="true"
      />
      <span class="whitespace-nowrap">{{
        $t('CONTACTS_PAGE.COLUMNS.TRIGGER')
      }}</span>
    </button>

    <div
      v-show="isOpen"
      role="dialog"
      aria-labelledby="contacts-columns-title"
      aria-describedby="contacts-columns-hint"
      class="absolute right-0 top-full z-50 mt-1.5 w-72
        rounded-xl border border-slate-100 dark:border-slate-700
        bg-white dark:bg-slate-800
        shadow-lg shadow-slate-900/10 dark:shadow-black/40
        p-4 overscroll-contain touch-manipulation"
    >
      <p
        id="contacts-columns-title"
        class="m-0 text-sm font-semibold text-slate-900 dark:text-slate-100 text-pretty"
      >
        {{ $t('CONTACTS_PAGE.COLUMNS.TITLE') }}
      </p>
      <p
        id="contacts-columns-hint"
        class="m-0 mt-1 text-xs leading-snug text-slate-500 dark:text-slate-400"
      >
        {{ $t('CONTACTS_PAGE.COLUMNS.HINT') }}
      </p>

      <div class="mt-3 max-h-80 overflow-y-auto overscroll-contain">
        <ul class="m-0 p-0 list-none flex flex-col gap-0.5">
          <li v-for="col in standardColumns" :key="col.key">
            <label
              class="flex items-center gap-2.5 min-h-[2.25rem] px-2 py-1.5 rounded-lg cursor-pointer
                hover:bg-slate-50 dark:hover:bg-slate-700/60
                has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-woot-500"
            >
              <input
                type="checkbox"
                class="h-4 w-4 shrink-0 rounded border-slate-300 dark:border-slate-500
                  text-woot-500 focus:ring-0 focus-visible:ring-2 focus-visible:ring-woot-500
                  dark:bg-slate-900 cursor-pointer"
                :checked="isChecked(col.key)"
                :name="`contact-column-${col.key}`"
                autocomplete="off"
                @change="onToggle(col.key)"
              />
              <span
                class="text-sm text-slate-800 dark:text-slate-100 min-w-0 truncate"
              >
                {{ columnLabel(col) }}
              </span>
            </label>
          </li>
        </ul>

        <template v-if="attributeColumns.length">
          <p
            class="m-0 mt-3 mb-1 px-2 text-xs font-medium uppercase tracking-wide
              text-slate-500 dark:text-slate-400"
          >
            {{ $t('CONTACTS_PAGE.COLUMNS.ATTRIBUTES_SECTION') }}
          </p>
          <ul class="m-0 p-0 list-none flex flex-col gap-0.5">
            <li v-for="col in attributeColumns" :key="col.key">
              <label
                class="flex items-center gap-2.5 min-h-[2.25rem] px-2 py-1.5 rounded-lg cursor-pointer
                  hover:bg-slate-50 dark:hover:bg-slate-700/60
                  has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-woot-500"
              >
                <input
                  type="checkbox"
                  class="h-4 w-4 shrink-0 rounded border-slate-300 dark:border-slate-500
                    text-woot-500 focus:ring-0 focus-visible:ring-2 focus-visible:ring-woot-500
                    dark:bg-slate-900 cursor-pointer"
                  :checked="isChecked(col.key)"
                  :name="`contact-column-${col.key}`"
                  autocomplete="off"
                  @change="onToggle(col.key)"
                />
                <span
                  class="text-sm text-slate-800 dark:text-slate-100 min-w-0 truncate"
                  :title="columnLabel(col)"
                >
                  {{ columnLabel(col) }}
                </span>
              </label>
            </li>
          </ul>
        </template>
      </div>
    </div>
  </div>
</template>
