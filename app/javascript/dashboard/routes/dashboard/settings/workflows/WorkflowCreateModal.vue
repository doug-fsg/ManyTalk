<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'dashboard/composables/route';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'dashboard/composables/useI18n';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close']);

const store = useStore();
const router = useRouter();
const { t, te } = useI18n();

const step = ref('choose');
const templates = ref([]);
const isLoadingTemplates = ref(false);
const isCreating = ref(false);
const creatingKey = ref(null);
const selectedCategory = ref('all');
const brokenImages = ref({});

const CATEGORY_KEYS = [
  'all',
  'atendimento',
  'vendas',
  'operacional',
  'marketing',
];

watch(
  () => props.show,
  visible => {
    if (visible) {
      step.value = 'choose';
      templates.value = [];
      selectedCategory.value = 'all';
      brokenImages.value = {};
    }
  }
);

const close = () => emit('close');

const openBlank = () => {
  close();
  router.push({ name: 'workflows_new' });
};

const openGallery = async () => {
  step.value = 'gallery';
  isLoadingTemplates.value = true;
  try {
    templates.value = await store.dispatch('workflows/getTemplates');
  } catch {
    useAlert(t('WORKFLOW.CREATE.TEMPLATES_ERROR'));
    step.value = 'choose';
  } finally {
    isLoadingTemplates.value = false;
  }
};

const selectTemplate = async template => {
  if (isCreating.value) return;
  isCreating.value = true;
  creatingKey.value = template.key;
  try {
    const workflow = await store.dispatch(
      'workflows/createFromTemplate',
      template.key
    );
    close();
    router.push({
      name: 'workflows_edit',
      params: { workflowId: workflow.id },
    });
  } catch {
    useAlert(t('WORKFLOW.CREATE.TEMPLATE_CREATE_ERROR'));
  } finally {
    isCreating.value = false;
    creatingKey.value = null;
  }
};

const categoryLabel = categoryKey => {
  if (categoryKey === 'all') return t('WORKFLOW.CREATE.FILTER_ALL');
  const path = `WORKFLOW.CREATE.CATEGORIES.${categoryKey}`;
  if (te(path)) return t(path);
  return categoryKey;
};

const filteredTemplates = computed(() => {
  if (selectedCategory.value === 'all') return templates.value;
  return templates.value.filter(
    template => template.category === selectedCategory.value
  );
});

const templateImageUrl = key =>
  `/assets/images/dashboard/workflows/templates/${key}.png`;

const onImageError = key => {
  brokenImages.value = { ...brokenImages.value, [key]: true };
};

const hasTemplateImage = key => !brokenImages.value[key];

const modalSize = computed(() => (step.value === 'gallery' ? 'large' : ''));
</script>

<template>
  <woot-modal :show="show" :size="modalSize" :on-close="close">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="
          step === 'gallery'
            ? $t('WORKFLOW.CREATE.GALLERY_TITLE')
            : $t('WORKFLOW.CREATE.TITLE')
        "
        :header-content="
          step === 'gallery'
            ? $t('WORKFLOW.CREATE.GALLERY_DESC')
            : $t('WORKFLOW.CREATE.DESC')
        "
      />

      <!-- Step: choose -->
      <div v-if="step === 'choose'" class="flex flex-col gap-3 px-8 pb-8">
        <button
          type="button"
          class="w-full flex items-start gap-4 p-4 text-left rounded-lg border border-solid border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
          @click="openBlank"
        >
          <div
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-white dark:bg-slate-700 border border-slate-75 dark:border-slate-600"
            aria-hidden="true"
          >
            <svg
              class="h-5 w-5 text-slate-600 dark:text-slate-300"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M12 4v16m8-8H4"
              />
            </svg>
          </div>
          <div class="min-w-0">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.CREATE.BLANK_TITLE') }}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-0.5">
              {{ $t('WORKFLOW.CREATE.BLANK_DESC') }}
            </p>
          </div>
        </button>

        <button
          type="button"
          class="w-full flex items-start gap-4 p-4 text-left rounded-lg border border-solid border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-150 cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
          @click="openGallery"
        >
          <div
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-white dark:bg-slate-700 border border-slate-75 dark:border-slate-600"
            aria-hidden="true"
          >
            <svg
              class="h-5 w-5 text-slate-600 dark:text-slate-300"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
              />
            </svg>
          </div>
          <div class="min-w-0">
            <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('WORKFLOW.CREATE.TEMPLATES_TITLE') }}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-0.5">
              {{ $t('WORKFLOW.CREATE.TEMPLATES_DESC') }}
            </p>
          </div>
        </button>
      </div>

      <!-- Step: gallery -->
      <div v-else class="px-8 pb-8">
        <!-- Category filters -->
        <div class="flex flex-wrap gap-2 mb-6">
          <button
            v-for="categoryKey in CATEGORY_KEYS"
            :key="categoryKey"
            type="button"
            class="px-3 py-1.5 text-xs font-medium rounded-full border transition-colors duration-150 cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
            :class="
              selectedCategory === categoryKey
                ? 'bg-woot-500 border-woot-500 text-white'
                : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-slate-300 dark:hover:border-slate-600'
            "
            @click="selectedCategory = categoryKey"
          >
            {{ categoryLabel(categoryKey) }}
          </button>
        </div>

        <div
          v-if="isLoadingTemplates"
          class="flex items-center justify-center py-12 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('WORKFLOW.CREATE.TEMPLATES_LOADING') }}
        </div>

        <div
          v-else-if="!filteredTemplates.length"
          class="flex items-center justify-center py-12 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('WORKFLOW.CREATE.TEMPLATES_EMPTY') }}
        </div>

        <div
          v-else
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 overflow-y-auto max-h-[70vh]"
        >
          <!-- Blank card -->
          <button
            v-if="selectedCategory === 'all'"
            type="button"
            class="flex flex-col text-left rounded-xl border border-dashed border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800/50 hover:border-woot-400 dark:hover:border-woot-500 hover:bg-woot-50/30 dark:hover:bg-woot-900/10 transition-colors duration-150 cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500 group"
            @click="openBlank"
          >
            <div
              class="relative w-full aspect-[7/4] rounded-t-xl bg-slate-50 dark:bg-slate-800 border-b border-slate-100 dark:border-slate-700 overflow-hidden"
            >
              <img
                v-if="hasTemplateImage('blank')"
                :src="templateImageUrl('blank')"
                :alt="$t('WORKFLOW.CREATE.BLANK_TITLE')"
                class="absolute inset-0 w-full h-full object-cover"
                @error="onImageError('blank')"
              />
              <div
                v-else
                class="absolute inset-0 flex items-center justify-center"
              >
                <svg
                  class="h-8 w-8 text-slate-300 dark:text-slate-600 group-hover:text-woot-400 transition-colors"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M12 4v16m8-8H4"
                  />
                </svg>
              </div>
            </div>
            <div class="flex flex-col flex-1 gap-2 p-4">
              <p
                class="text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ $t('WORKFLOW.CREATE.BLANK_TITLE') }}
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400 flex-1">
                {{ $t('WORKFLOW.CREATE.BLANK_DESC') }}
              </p>
              <span
                class="mt-2 block w-full text-center text-xs font-medium py-2 rounded-lg border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 group-hover:bg-woot-500 group-hover:text-white group-hover:border-woot-500 transition-colors"
              >
                {{ $t('WORKFLOW.CREATE.BLANK_CTA') }}
              </span>
            </div>
          </button>

          <!-- Template cards -->
          <button
            v-for="template in filteredTemplates"
            :key="template.key"
            type="button"
            :disabled="isCreating"
            class="flex flex-col text-left rounded-xl border border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800 hover:border-woot-400 dark:hover:border-woot-500 hover:shadow-md transition-all duration-150 cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-woot-500 disabled:opacity-60 disabled:cursor-not-allowed group"
            @click="selectTemplate(template)"
          >
            <div
              class="relative w-full aspect-[7/4] rounded-t-xl border-b border-slate-100 dark:border-slate-700 overflow-hidden bg-slate-100 dark:bg-slate-900"
            >
              <img
                v-if="hasTemplateImage(template.key)"
                :src="templateImageUrl(template.key)"
                :alt="template.name"
                class="absolute inset-0 w-full h-full object-cover"
                @error="onImageError(template.key)"
              />
            </div>

            <div class="flex flex-col flex-1 gap-2 p-4">
              <span
                v-if="template.category"
                class="self-start text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
              >
                {{ categoryLabel(template.category) }}
              </span>

              <p
                class="text-sm font-semibold text-slate-800 dark:text-slate-100 leading-snug"
              >
                {{ template.name }}
              </p>
              <p
                class="text-xs text-slate-500 dark:text-slate-400 flex-1 line-clamp-2"
              >
                {{ template.description }}
              </p>

              <div
                class="flex items-center gap-1 text-xs text-slate-400 dark:text-slate-500"
              >
                <svg
                  class="w-3.5 h-3.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                  />
                </svg>
                {{ template.step_count }} {{ $t('WORKFLOW.LIST.STEPS') }}
              </div>

              <span
                class="mt-2 block w-full text-center text-xs font-medium py-2 rounded-lg bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border border-slate-100 dark:border-slate-600 group-hover:bg-woot-500 group-hover:text-white group-hover:border-woot-500 transition-colors"
                :class="{
                  'bg-woot-500 text-white border-woot-500':
                    creatingKey === template.key,
                }"
              >
                {{
                  creatingKey === template.key
                    ? $t('WORKFLOW.CREATE.CREATING')
                    : $t('WORKFLOW.CREATE.USE_TEMPLATE')
                }}
              </span>
            </div>
          </button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
