<template>
  <div class="w-full">
    <div class="templates__list-search gap-1">
      <fluent-icon icon="search" class="search-icon" size="16" />
      <input
        ref="search"
        v-model="query"
        type="search"
        :placeholder="$t('WHATSAPP_TEMPLATES.PICKER.SEARCH_PLACEHOLDER')"
        class="templates__search-input"
      />
    </div>
    <p v-if="isSyncing" class="templates__sync-status">
      {{ $t('WHATSAPP_TEMPLATES.PICKER.SYNCING') }}
    </p>
    <div class="template__list-container" :class="{ 'template__list-container--compact': compact }">
      <whatsapp-template-guide
        v-if="showEmptyGuide"
        :inbox-id="inboxId"
        @synced="$emit('synced')"
      />
      <template v-else>
        <div v-for="(template, i) in filteredTemplateMessages" :key="template.id">
          <button
            class="template__list-item"
            :class="{ 'template__list-item--compact': compact }"
            @click="$emit('onSelect', template)"
          >
            <div>
              <div class="flex items-center justify-between gap-2" :class="{ 'mb-0': compact }">
                <p class="label-title" :class="{ 'label-title--compact': compact }">
                  {{ template.name }}
                </p>
                <span
                  class="inline-block py-0.5 px-1.5 rounded-sm text-xs leading-none cursor-default bg-white dark:bg-slate-700 text-slate-500 dark:text-slate-300 shrink-0"
                >
                  {{ template.language }}
                </span>
              </div>
              <template v-if="!compact">
                <div>
                  <p class="strong">
                    {{ $t('WHATSAPP_TEMPLATES.PICKER.LABELS.TEMPLATE_BODY') }}
                  </p>
                  <p class="label-body">{{ getTemplatebody(template) }}</p>
                </div>
                <div class="label-category">
                  <p class="strong">
                    {{ $t('WHATSAPP_TEMPLATES.PICKER.LABELS.CATEGORY') }}
                  </p>
                  <p>{{ template.category }}</p>
                </div>
              </template>
            </div>
          </button>
          <hr v-if="i != filteredTemplateMessages.length - 1" :key="`hr-${i}`" />
        </div>
        <div v-if="!filteredTemplateMessages.length">
          <p>
            {{ $t('WHATSAPP_TEMPLATES.PICKER.NO_TEMPLATES_FOUND') }}
            <strong>{{ query }}</strong>
          </p>
        </div>
      </template>
    </div>
  </div>
</template>

<script>
import WhatsappTemplateGuide from './WhatsappTemplateGuide.vue';
import whatsappTemplateGuideMixin from 'dashboard/mixins/whatsappTemplateGuideMixin';

// TODO: Remove this when we support all formats
const formatsToRemove = ['DOCUMENT', 'IMAGE', 'VIDEO'];

export default {
  components: {
    WhatsappTemplateGuide,
  },
  mixins: [whatsappTemplateGuideMixin],
  props: {
    inboxId: {
      type: Number,
      default: undefined,
    },
    compact: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      query: '',
    };
  },
  computed: {
    inbox() {
      return this.$store.getters['inboxes/getInboxes'].find(
        record => record.id === Number(this.inboxId)
      );
    },
    isWhatsAppCloudInbox() {
      return (
        this.inbox?.channel_type === 'Channel::Whatsapp' &&
        this.inbox?.provider === 'whatsapp_cloud'
      );
    },
    whatsAppTemplateMessages() {
      // TODO: Remove the last filter when we support all formats
      return this.$store.getters['inboxes/getWhatsAppTemplates'](this.inboxId)
        .filter(template => template.status.toLowerCase() === 'approved')
        .filter(template => {
          return template.components.every(component => {
            return !formatsToRemove.includes(component.format);
          });
        });
    },
    filteredTemplateMessages() {
      return this.whatsAppTemplateMessages.filter(template =>
        template.name.toLowerCase().includes(this.query.toLowerCase())
      );
    },
    showEmptyGuide() {
      return (
        this.isWhatsAppCloudInbox &&
        !this.query &&
        this.whatsAppTemplateMessages.length === 0 &&
        !this.isSyncing
      );
    },
  },
  mounted() {
    this.maybeSyncWhatsAppTemplates();
  },
  methods: {
    getTemplatebody(template) {
      return template.components.find(component => component.type === 'BODY')
        .text;
    },
  },
};
</script>

<style scoped lang="scss">
.templates__list-search {
  @apply items-center flex bg-slate-25 dark:bg-slate-900 mb-2.5 py-0 px-2.5 rounded-md border border-solid border-slate-100 dark:border-slate-700;

  .search-icon {
    @apply text-slate-400 dark:text-slate-300;
  }

  .templates__search-input {
    @apply bg-transparent border-0 text-xs h-9 m-0;
  }
}

.templates__sync-status {
  @apply text-xs text-slate-500 dark:text-slate-400 mb-2;
}
.template__list-container {
  @apply bg-slate-25 dark:bg-slate-900 rounded-md max-h-[18.75rem] overflow-y-auto p-2.5;

  &--compact {
    @apply max-h-[12rem] p-1.5;
  }

  .template__list-item {
    @apply rounded-lg cursor-pointer block p-2.5 text-left w-full hover:bg-woot-50 dark:hover:bg-slate-800;

    &--compact {
      @apply py-2 px-2;
    }

    .label-title {
      @apply text-sm;

      &--compact {
        @apply text-xs font-medium truncate;
      }
    }

    .label-category {
      @apply mt-5;

      span {
        @apply text-sm font-semibold;
      }
    }

    .label-body {
      font-family: monospace;
    }
  }
}

.strong {
  @apply text-xs font-semibold;
}

hr {
  @apply border-b border-solid border-slate-100 dark:border-slate-700 my-2.5 mx-auto max-w-[95%];
}
</style>
