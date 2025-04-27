import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import Vue from 'vue';
import types from '../../mutation-types';
import ContactAPI from '../../../api/contacts';
import AccountActionsAPI from '../../../api/accountActions';
import AnalyticsHelper from '../../../helper/AnalyticsHelper';
import { CONTACTS_EVENTS } from '../../../helper/AnalyticsHelper/events';

const buildContactFormData = contactParams => {
  const formData = new FormData();
  const { additional_attributes = {}, ...contactProperties } = contactParams;
  Object.keys(contactProperties).forEach(key => {
    if (contactProperties[key]) {
      formData.append(key, contactProperties[key]);
    }
  });
  const { social_profiles, ...additionalAttributesProperties } =
    additional_attributes;
  Object.keys(additionalAttributesProperties).forEach(key => {
    formData.append(
      `additional_attributes[${key}]`,
      additionalAttributesProperties[key]
    );
  });
  Object.keys(social_profiles).forEach(key => {
    formData.append(
      `additional_attributes[social_profiles][${key}]`,
      social_profiles[key]
    );
  });
  return formData;
};

export const raiseContactCreateErrors = error => {
  if (error.response?.status === 422) {
    throw new DuplicateContactException(error.response.data.attributes);
  } else if (error.response?.data?.message) {
    throw new ExceptionWithMessage(error.response.data.message);
  } else {
    throw new Error(error);
  }
};

// Fallback para o caso de não haver bus global
const eventBus = new Vue();

export const actions = {
  search: async ({ commit }, { search, page, sortAttr, label }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.search(search, page, sortAttr, label);
      commit(types.CLEAR_CONTACTS);
      commit(types.SET_CONTACTS, payload);
      commit(types.SET_CONTACT_META, meta);
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    }
  },

  get: async ({ commit }, { page = 1, sortAttr, label } = {}) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.get(page, sortAttr, label);
      commit(types.CLEAR_CONTACTS);
      commit(types.SET_CONTACTS, payload);
      commit(types.SET_CONTACT_META, meta);
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    }
  },

  show: async ({ commit }, { id }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await ContactAPI.show(id);
      commit(types.SET_CONTACT_ITEM, response.data.payload);
      commit(types.SET_CONTACT_UI_FLAG, {
        isFetchingItem: false,
      });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, {
        isFetchingItem: false,
      });
    }
  },

  update: async ({ commit }, { id, isFormData = false, ...contactParams }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isUpdating: true });
    try {
      const response = await ContactAPI.update(
        id,
        isFormData ? buildContactFormData(contactParams) : contactParams
      );
      commit(types.EDIT_CONTACT, response.data.payload);
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
      if (error.response?.status === 422) {
        throw new DuplicateContactException(error.response.data.attributes);
      } else {
        throw new Error(error);
      }
    }
  },

  create: async ({ commit }, { isFormData = false, ...contactParams }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isCreating: true });
    try {
      const response = await ContactAPI.create(
        isFormData ? buildContactFormData(contactParams) : contactParams
      );

      AnalyticsHelper.track(CONTACTS_EVENTS.CREATE_CONTACT);
      commit(types.SET_CONTACT_ITEM, response.data.payload.contact);
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
      return response.data.payload.contact;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
      return raiseContactCreateErrors(error);
    }
  },

  import: async ({ commit }, file) => {
    commit(types.SET_CONTACT_UI_FLAG, { isCreating: true });
    try {
      await ContactAPI.importContacts(file);
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
      if (error.response?.data?.message) {
        throw new ExceptionWithMessage(error.response.data.message);
      }
    }
  },

  export: async ({ commit }, { payload, label }) => {
    try {
      await ContactAPI.exportContacts({ payload, label });

      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      } else {
        throw new Error(error);
      }
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_CONTACT_UI_FLAG, { isDeleting: true });
    try {
      await ContactAPI.delete(id);
      commit(types.SET_CONTACT_UI_FLAG, { isDeleting: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isDeleting: false });
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      } else {
        throw new Error(error);
      }
    }
  },

  deleteCustomAttributes: async ({ commit }, { id, customAttributes }) => {
    try {
      const response = await ContactAPI.destroyCustomAttributes(id, customAttributes);
      
      commit(types.EDIT_CONTACT, response.data.payload);
    } catch (error) {
      throw new Error(error);
    }
  },

  deleteAvatar: async ({ commit }, id) => {
    try {
      const response = await ContactAPI.destroyAvatar(id);
      commit(types.EDIT_CONTACT, response.data.payload);
    } catch (error) {
      throw new Error(error);
    }
  },

  fetchContactableInbox: async ({ commit }, id) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetchingInboxes: true });
    try {
      const response = await ContactAPI.getContactableInboxes(id);
      const contact = {
        id,
        contactableInboxes: response.data.payload,
      };
      commit(types.SET_CONTACT_ITEM, contact);
    } catch (error) {
      if (error.response?.data?.message) {
        throw new ExceptionWithMessage(error.response.data.message);
      } else {
        throw new Error(error);
      }
    } finally {
      commit(types.SET_CONTACT_UI_FLAG, { isFetchingInboxes: false });
    }
  },

  updatePresence: ({ commit }, data) => {
    commit(types.UPDATE_CONTACTS_PRESENCE, data);
  },

  setContact({ commit }, data) {
    commit(types.SET_CONTACT_ITEM, data);
  },

  merge: async ({ commit }, { childId, parentId }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isMerging: true });
    try {
      const response = await AccountActionsAPI.merge(parentId, childId);
      commit(types.SET_CONTACT_ITEM, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CONTACT_UI_FLAG, { isMerging: false });
    }
  },

  deleteContactThroughConversations: ({ commit }, id) => {
    commit(types.DELETE_CONTACT, id);
    commit(types.CLEAR_CONTACT_CONVERSATIONS, id, { root: true });
    commit(`contactConversations/${types.DELETE_CONTACT_CONVERSATION}`, id, {
      root: true,
    });
  },

  updateContact: async ({ commit }, { id, skipEventEmit = false, _fromKanban = false, _kanbanOperation = null, _kanbanUpdateTimestamp = null, ...contactParams }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isUpdating: true });
    
    try {
      // Chamar a API para atualizar o contato
      const response = await ContactAPI.updateContact(id, contactParams);
      
      // Atualizar o estado no store
      commit(types.EDIT_CONTACT, response.data.payload);
      
      // Se tem atributos customizados E não está marcado para pular a emissão de eventos
      if (contactParams.custom_attributes && !skipEventEmit) {
        const bus = Vue.prototype.$bus || eventBus;
        
        // Incluir todos os flags kanban no payload do evento
        const eventPayload = { 
          _fromKanban,
          _kanbanOperation,
          _kanbanUpdateTimestamp,
        };
        
        // Adicionar log para depuração
        if (_fromKanban) {
          console.log(
            '[ContactStore] Emitindo evento com flag kanban:',
            eventPayload
          );
        }
        
        // Evitar emitir eventos de atualização secundários se a operação veio do Kanban
        // Isso impede que novas atualizações sejam processadas em cascata
        if (!_fromKanban) {
          bus.$emit(
            'contact_attribute_updated',
            response.data.payload,
            contactParams.custom_attributes,
            eventPayload
          );
        }
      }
      
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
      return response.data.payload;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
      throw new Error(error);
    }
  },

  filter: async (
    { commit },
    { page = 1, sortAttr, queryPayload, resetState = true } = {}
  ) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.filter(page, sortAttr, queryPayload);
      if (resetState) {
        commit(types.CLEAR_CONTACTS);
        commit(types.SET_CONTACTS, payload);
        commit(types.SET_CONTACT_META, meta);
        commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
      }
      return payload;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    }
    return [];
  },

  setContactFilters({ commit }, data) {
    commit(types.SET_CONTACT_FILTERS, data);
  },

  clearContactFilters({ commit }) {
    commit(types.CLEAR_CONTACT_FILTERS);
  },

  deleteContactCustomAttribute: async (
    { commit },
    { id, attributeKey, fromKanban = false, _kanbanOperation = null }
  ) => {
    commit(types.SET_CONTACT_UI_FLAG, { isUpdating: true });
    
    try {
      // Enviar a chave como array para a API
      const response = await ContactAPI.destroyCustomAttributes(id, [attributeKey]);
      
      // Atualizar o contato no store
      commit(types.EDIT_CONTACT, response.data.payload);
      
      // Emitir evento com informações completas sobre a origem
      const bus = Vue.prototype.$bus || eventBus;
      if (bus) {
        // Escolher o evento correto com base na origem
        const eventName = fromKanban 
          ? 'contact_attribute_removed_from_kanban' 
          : 'contact_attribute_removed';
          
        // Adicionar informações completas no payload
        const eventPayload = {
          fromKanban,
          _kanbanOperation,
        };
        
        bus.$emit(eventName, id, attributeKey, eventPayload);
      }
      
      return response.data.payload;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
      throw new Error(error);
    } finally {
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
    }
  },
};
