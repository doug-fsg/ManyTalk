import languages from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import countries from 'shared/constants/countries';
import {
  generateCustomAttributeTypes,
  getActionOptions,
  getConditionOptions,
  getCustomAttributeInputType,
  getOperatorTypes,
  isACustomAttribute,
  getFileName,
  getDefaultConditions,
  getDefaultActions,
  filterCustomAttributes,
  generateAutomationPayload,
  getStandardAttributeInputType,
  isCustomAttribute,
  generateCustomAttributes,
} from 'dashboard/helper/automationHelper';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      campaigns: 'campaigns/getAllCampaigns',
      contacts: 'contacts/getContacts',
      inboxes: 'inboxes/getInboxes',
      labels: 'labels/getLabels',
      teams: 'teams/getTeams',
      slaPolicies: 'sla/getSLA',
    }),
    booleanFilterOptions() {
      return [
        {
          id: true,
          name: this.$t('FILTER.ATTRIBUTE_LABELS.TRUE'),
        },
        {
          id: false,
          name: this.$t('FILTER.ATTRIBUTE_LABELS.FALSE'),
        },
      ];
    },

    statusFilterOptions() {
      const statusFilters = this.$t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS');
      return [
        ...Object.keys(statusFilters).map(status => {
          return {
            id: status,
            name: statusFilters[status].TEXT,
          };
        }),
        {
          id: 'all',
          name: this.$t('CHAT_LIST.FILTER_ALL'),
        },
      ];
    },
  },
  methods: {
    getFileName,
    onEventChange() {
      this.automation.conditions = getDefaultConditions(
        this.automation.event_name
      );
      this.automation.actions = getDefaultActions();
    },
    getAttributes(key) {
      return this.automationTypes[key].conditions;
    },
    getInputType(key) {
      const customAttribute = isACustomAttribute(this.allCustomAttributes, key);
      if (customAttribute) {
        // Se for um atributo kanban, usar kanban_stage_select
        if (customAttribute.is_kanban) {
          return 'kanban_stage_select';
        }
        return getCustomAttributeInputType(
          customAttribute.attribute_display_type
        );
      }
      const type = this.getAutomationType(key);
      return type.inputType;
    },
    getOperators(key) {
      if (this.mode === 'edit') {
        const customAttribute = isACustomAttribute(
          this.allCustomAttributes,
          key
        );
        if (customAttribute) {
          return getOperatorTypes(customAttribute.attribute_display_type);
        }
      }
      const type = this.getAutomationType(key);
      return type.filterOperators;
    },
    getAutomationType(key) {
      return this.automationTypes[this.automation.event_name].conditions.find(
        condition => condition.key === key
      );
    },
    getCustomAttributeType(key) {
      const type = this.automationTypes[
        this.automation.event_name
      ].conditions.find(i => i.key === key).customAttributeType;
      return type;
    },
    getConditionDropdownValues(type) {
      // Verificar se é um atributo kanban
      const customAttribute = isACustomAttribute(this.allCustomAttributes, type);
      if (customAttribute && customAttribute.is_kanban) {
        // Para atributos kanban, retornar as etapas (attribute_values) do atributo específico
        const stages = customAttribute.attribute_values || [];
        return stages.map(stage => ({
          id: stage,
          name: stage
        }));
      }
      
      const {
        agents,
        allCustomAttributes: customAttributes,
        booleanFilterOptions,
        campaigns,
        contacts,
        inboxes,
        statusFilterOptions,
        teams,
      } = this;
      
      // Buscar atributos kanban do store
      const kanbanAttributes = this.$store.getters['attributes/getAttributes']
        .filter(attr => attr.attribute_model === 'contact_attribute' && attr.is_kanban === true);
      
      return getConditionOptions({
        agents,
        booleanFilterOptions,
        campaigns,
        contacts,
        customAttributes,
        inboxes,
        statusFilterOptions,
        teams,
        languages,
        countries,
        kanbanAttributes,
        type,
      });
    },
    appendNewCondition() {
      this.automation.conditions.push(
        ...getDefaultConditions(this.automation.event_name)
      );
    },
    appendNewAction() {
      this.automation.actions.push(...getDefaultActions());
    },
    removeFilter(index) {
      if (this.automation.conditions.length <= 1) {
        useAlert(this.$t('AUTOMATION.CONDITION.DELETE_MESSAGE'));
      } else {
        this.automation.conditions.splice(index, 1);
      }
    },
    removeAction(index) {
      if (this.automation.actions.length <= 1) {
        useAlert(this.$t('AUTOMATION.ACTION.DELETE_MESSAGE'));
      } else {
        this.automation.actions.splice(index, 1);
      }
    },
    submitAutomation() {
      this.$v.$touch();
      if (this.$v.$invalid) return;
      const automation = generateAutomationPayload(this.automation);
      this.$emit('saveAutomation', automation, this.mode);
    },
    resetFilter(index, currentCondition) {
      this.automation.conditions[index].filter_operator = this.automationTypes[
        this.automation.event_name
      ].conditions.find(
        condition => condition.key === currentCondition.attribute_key
      ).filterOperators[0].value;
      this.automation.conditions[index].values = '';
    },
    showUserInput(type) {
      return !(type === 'is_present' || type === 'is_not_present');
    },
    showActionInput(action) {
      if (action === 'send_email_to_team' || action === 'send_message')
        return false;
      const type = this.automationActionTypes.find(
        i => i.key === action
      ).inputType;
      return !!type;
    },
    resetAction(index) {
      this.automation.actions[index].action_params = [];
    },
    manifestConditions(automation) {
      const customAttributes = filterCustomAttributes(this.allCustomAttributes);
      const conditions = automation.conditions.map(condition => {
        // Usar o mesmo método getInputType para consistência
        let inputType = this.getInputType(condition.attribute_key);
        if (inputType === 'plain_text' || inputType === 'date') {
          return {
            ...condition,
            values: condition.values[0],
          };
        }
        if (inputType === 'comma_separated_plain_text') {
          return {
            ...condition,
            values: condition.values.join(','),
          };
        }
        if (inputType === 'kanban_stage_select') {
          // Para atributos kanban, os valores salvos são apenas o nome do estágio
          // Precisamos converter para o formato que o multiselect espera
          const stageName = condition.values[0];
          if (stageName) {
            return {
              ...condition,
              values: [{ id: stageName, name: stageName }]
            };
          }
          return {
            ...condition,
            values: []
          };
        }
        return {
          ...condition,
          query_operator: condition.query_operator || 'and',
          values: [
            ...this.getConditionDropdownValues(condition.attribute_key),
          ].filter(item => [...condition.values].includes(item.id)),
        };
      });
      return conditions;
    },
    generateActionsArray(action) {
      const params = action.action_params;
      let actionParams = [];
      const inputType = this.automationActionTypes.find(
        item => item.key === action.action_name
      ).inputType;
      if (inputType === 'multi_select' || inputType === 'search_select') {
        actionParams = [
          ...this.getActionDropdownValues(action.action_name),
        ].filter(item => [...params].includes(item.id));
      } else if (inputType === 'team_message') {
        actionParams = {
          team_ids: [
            ...this.getActionDropdownValues(action.action_name),
          ].filter(item => [...params[0].team_ids].includes(item.id)),
          message: params[0].message,
        };
      } else actionParams = [...params];
      return actionParams;
    },
    manifestActions(automation) {
      let actionParams = [];
      const actions = automation.actions.map(action => {
        if (action.action_params.length) {
          actionParams = this.generateActionsArray(action);
        }
        return {
          ...action,
          action_params: actionParams,
        };
      });
      return actions;
    },
    formatAutomation(automation) {
      this.automation = {
        ...automation,
        conditions: this.manifestConditions(automation),
        actions: this.manifestActions(automation),
      };
    },
    getActionDropdownValues(type) {
      const { agents, labels, teams, slaPolicies } = this;
      
      // Buscar atributos kanban do store para ações
      const kanbanAttributes = this.$store.getters['attributes/getAttributes']
        .filter(attr => attr.attribute_model === 'contact_attribute' && attr.is_kanban === true);
      
      return getActionOptions({
        agents,
        labels,
        teams,
        slaPolicies,
        languages,
        kanbanAttributes,
        type,
      });
    },
    manifestCustomAttributes() {
      const conversationCustomAttributesRaw = this.$store.getters[
        'attributes/getAttributesByModel'
      ]('conversation_attribute');

      const contactCustomAttributesRaw =
        this.$store.getters['attributes/getAttributesByModel'](
          'contact_attribute'
        );
      
      // Incluir também os atributos kanban (que são excluídos pelo getAttributesByModel)
      const kanbanAttributesRaw = this.$store.getters['attributes/getAttributes']
        .filter(attr => attr.attribute_model === 'contact_attribute' && attr.is_kanban === true);
      
      // Combinar atributos customizados normais com kanban
      const allContactAttributesRaw = [...contactCustomAttributesRaw, ...kanbanAttributesRaw];
      const conversationCustomAttributeTypes = generateCustomAttributeTypes(
        conversationCustomAttributesRaw,
        'conversation_attribute'
      );
      const contactCustomAttributeTypes = generateCustomAttributeTypes(
        allContactAttributesRaw,
        'contact_attribute'
      );
      let manifestedCustomAttributes = generateCustomAttributes(
        conversationCustomAttributeTypes,
        contactCustomAttributeTypes,
        this.$t('AUTOMATION.CONDITION.CONVERSATION_CUSTOM_ATTR_LABEL'),
        this.$t('AUTOMATION.CONDITION.CONTACT_CUSTOM_ATTR_LABEL')
      );
      this.automationTypes.message_created.conditions.push(
        ...manifestedCustomAttributes
      );
      this.automationTypes.conversation_created.conditions.push(
        ...manifestedCustomAttributes
      );
      this.automationTypes.conversation_updated.conditions.push(
        ...manifestedCustomAttributes
      );
      this.automationTypes.conversation_resolved.conditions.push(
        ...manifestedCustomAttributes
      );
      this.automationTypes.conversation_opened.conditions.push(
        ...manifestedCustomAttributes
      );
    },
  },
};
