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
import ContactAPI from 'dashboard/api/contacts';
import { getPipelinePosition, getPosition } from 'dashboard/routes/dashboard/crm/utils/pipelinePositionsHelper';

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
        // Para atributos kanban, verificar em pipeline_positions
        // Para outros atributos, verificar em custom_attributes
        let hasValue = false;
        if (attribute.is_kanban && this.contact.pipeline_positions) {
          const position = this.contact.pipeline_positions.find(
            p => p.pipeline_id === attribute.id
          );
          hasValue = !!position?.stage_id;
        } else {
          hasValue = Object.hasOwnProperty.call(
            this.customAttributes,
            attribute.attribute_key
          );
        }

        const isCheckbox = attribute.attribute_display_type === 'checkbox';
        const defaultValue = isCheckbox ? false : '';

        // Obter valor correto baseado no tipo de atributo
        let value = defaultValue;
        if (hasValue) {
          if (attribute.is_kanban && this.contact.pipeline_positions) {
            const position = this.contact.pipeline_positions.find(
              p => p.pipeline_id === attribute.id
            );
            value = position?.stage_id || defaultValue;
          } else {
            value = this.customAttributes[attribute.attribute_key];
          }
        }

        return {
          ...attribute,
          value: value,
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
    // Escutar atualizações de contato via ActionCable para sincronização em tempo real
    if (window.bus) {
      window.bus.$on('contact_updated', this.handleContactUpdate);
    }
  },
  beforeDestroy() {
    // Remover listener ao destruir componente
    if (window.bus) {
      window.bus.$off('contact_updated', this.handleContactUpdate);
    }
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
      // Verificar se é um atributo kanban
      const attribute = this.kanbanAttributes.find(attr => attr.attribute_key === key);
      
      if (attribute && attribute.is_kanban) {
        // Para atributos kanban, usar contact_pipeline_positions exclusivamente
        try {
          const currentPosition = getPipelinePosition(this.contact, attribute.id);
          const position = getPosition(this.contact, attribute.id) || 0;
          const dealValue = currentPosition?.deal_value || null;
          const metadata = currentPosition?.metadata || {};
          const enteredAt = currentPosition?.entered_at || new Date().toISOString();

          const response = await ContactAPI.updatePipelinePosition(
            this.contactId,
            attribute.id,
            value,
            position,
            enteredAt,
            dealValue,
            metadata
          );

          // SOLUÇÃO SIMPLES - apenas forçar re-render
          this.$forceUpdate();
          
          useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
        } catch (error) {
          const errorMessage =
            error?.response?.data?.error ||
            error?.response?.message ||
            this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR');
          useAlert(errorMessage);
        }
      } else {
        // Para atributos não-kanban, manter atualização de custom_attributes
        const updatedAttributes = { ...this.customAttributes, [key]: value };
        try {
          await this.$store.dispatch('contacts/update', {
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
      }
    },
    async onDelete(key) {
      // Verificar se é um atributo kanban
      const attribute = this.kanbanAttributes.find(attr => attr.attribute_key === key);
      
      if (attribute && attribute.is_kanban) {
        // Para atributos kanban, remover de contact_pipeline_positions
        try {
          await ContactAPI.deletePipelinePosition(this.contactId, attribute.id);
          
          // SOLUÇÃO SIMPLES - apenas forçar re-render
          this.$forceUpdate();
          
          useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.DELETE.SUCCESS'));
        } catch (error) {
          const errorMessage =
            error?.response?.data?.error ||
            error?.response?.message ||
            this.$t('CUSTOM_ATTRIBUTES.FORM.DELETE.ERROR');
          useAlert(errorMessage);
        }
      } else {
        // Para atributos não-kanban, manter remoção de custom_attributes
        try {
          await this.$store.dispatch('contacts/deleteCustomAttributes', {
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
      }
    },
    async onCopy(attributeValue) {
      await copyTextToClipboard(attributeValue);
      useAlert(this.$t('CUSTOM_ATTRIBUTES.COPY_SUCCESSFUL'));
    },
    handleContactUpdate(contactData) {
      // SOLUÇÃO SIMPLES - apenas forçar re-render se for o contato atual
      if (contactData && contactData.id === this.contactId) {
        this.$forceUpdate();
      }
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
