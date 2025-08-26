<template>
  <div class="custom-attributes--panel">
    <custom-attribute
      v-for="attribute in displayedAttributes"
      :key="attribute.id"
      :attribute-key="attribute.attribute_key"
      :attribute-type="attribute.attribute_display_type"
      :values="attribute.attribute_values"
      :label="attribute.attribute_display_name"
      :description="attribute.attribute_description"
      :value="attribute.value"
      :show-actions="true"
      :attribute-regex="attribute.regex_pattern"
      :regex-cue="attribute.regex_cue"
      :class="attributeClass"
      :contact-id="contactId"
      @update="onUpdate"
      @delete="onDelete"
      @copy="onCopy"
    />
    <p
      v-if="!displayedAttributes.length && emptyStateMessage"
      class="p-3 text-center"
    >
      {{ emptyStateMessage }}
    </p>
    <!-- Show more and show less buttons show it if the filteredAttributes length is greater than 5 -->
    <div v-if="filteredAttributes.length > 5" class="flex px-2 py-2">
      <woot-button
        size="small"
        :icon="showAllAttributes ? 'chevron-up' : 'chevron-down'"
        variant="clear"
        color-scheme="primary"
        class="!px-2 hover:!bg-transparent dark:hover:!bg-transparent"
        @click="onClickToggle"
      >
        {{ toggleButtonText }}
      </woot-button>
    </div>
  </div>
</template>

<script>
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import CustomAttribute from 'dashboard/components/CustomAttribute.vue';
import { mapGetters } from 'vuex';

export default {
  components: {
    CustomAttribute,
  },
  props: {
    attributeClass: {
      type: String,
      default: '',
    },
    contactId: { type: Number, default: null },
    attributeFrom: {
      type: String,
      required: true,
    },
    emptyStateMessage: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();

    return {
      uiSettings,
      updateUISettings,
    };
  },
  data() {
    return {
      showAllAttributes: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      accountId: 'getCurrentAccountId',
    }),
    // Get only kanban attributes (is_kanban = true) for contact_attribute type
    kanbanAttributes() {
      return this.$store.getters['attributes/getAttributes'].filter(
        record => record.attribute_model === 'contact_attribute' && record.is_kanban === true
      );
    },
    customAttributes() {
      return this.contact.custom_attributes || {};
    },
    contactIdentifier() {
      return (
        this.currentChat.meta?.sender?.id ||
        this.$route.params.contactId ||
        this.contactId
      );
    },
    contact() {
      return this.$store.getters['contacts/getContact'](this.contactIdentifier);
    },
    conversationId() {
      return this.currentChat.id;
    },
    toggleButtonText() {
      return !this.showAllAttributes
        ? this.$t('CUSTOM_ATTRIBUTES.SHOW_MORE')
        : this.$t('CUSTOM_ATTRIBUTES.SHOW_LESS');
    },
    filteredAttributes() {
      return this.kanbanAttributes.map(attribute => {
        // Check if the attribute key exists in customAttributes
        const hasValue = Object.hasOwnProperty.call(
          this.customAttributes,
          attribute.attribute_key
        );

        const isCheckbox = attribute.attribute_display_type === 'checkbox';
        const defaultValue = isCheckbox ? false : '';

        return {
          ...attribute,
          // Set value from customAttributes if it exists, otherwise use default value
          value: hasValue
            ? this.customAttributes[attribute.attribute_key]
            : defaultValue,
        };
      });
    },
    displayedAttributes() {
      // Show only the first 5 attributes or all depending on showAllAttributes
      if (this.showAllAttributes || this.filteredAttributes.length <= 5) {
        return this.filteredAttributes;
      }
      return this.filteredAttributes.slice(0, 5);
    },
    showMoreUISettingsKey() {
      return `show_all_attributes_${this.attributeFrom}`;
    },
  },
  mounted() {
    this.initializeSettings();
  },
  methods: {
    initializeSettings() {
      this.showAllAttributes =
        this.uiSettings[this.showMoreUISettingsKey] || false;
    },
    onClickToggle() {
      this.showAllAttributes = !this.showAllAttributes;
      this.updateUISettings({
        [this.showMoreUISettingsKey]: this.showAllAttributes,
      });
    },
    async onUpdate(key, value) {
      const updatedAttributes = { ...this.customAttributes, [key]: value };
      try {
        this.$store.dispatch('contacts/update', {
          id: this.contactId,
          custom_attributes: updatedAttributes,
        });
        useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
      } catch (error) {
        const errorMessage =
          error?.response?.message ||
          this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR');
        useAlert(errorMessage);
      }
    },
    async onDelete(key) {
      try {
        this.$store.dispatch('contacts/deleteCustomAttributes', {
          id: this.contactId,
          customAttributes: [key],
        });

        useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.DELETE.SUCCESS'));
      } catch (error) {
        const errorMessage =
          error?.response?.message ||
          this.$t('CUSTOM_ATTRIBUTES.FORM.DELETE.ERROR');
        useAlert(errorMessage);
      }
    },
    async onCopy(attributeValue) {
      await copyTextToClipboard(attributeValue);
      useAlert(this.$t('CUSTOM_ATTRIBUTES.COPY_SUCCESSFUL'));
    },
  },
};
</script>

<style scoped lang="scss">
.custom-attributes--panel {
  .conversation--attribute {
    @apply border-slate-50 dark:border-slate-700/50 border-b border-solid;
  }

  &.odd {
    .conversation--attribute {
      &:nth-child(2n + 1) {
        @apply bg-slate-25 dark:bg-slate-800/50;
      }
    }
  }

  &.even {
    .conversation--attribute {
      &:nth-child(2n) {
        @apply bg-slate-25 dark:bg-slate-800/50;
      }
    }
  }
}
</style>
