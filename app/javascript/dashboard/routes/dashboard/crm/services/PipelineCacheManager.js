export class PipelineCacheManager {
  constructor(store) {
    this.store = store;
    this.cache = {};
  }

  updateCache(pipelineId, pagination) {
    if (!pipelineId || !pagination) return;

    this.cache[pipelineId] = {
      contacts: this.store.getters['contacts/getContacts'],
      meta: this.store.getters['contacts/getMeta'],
      pagination: { ...pagination },
      lastUpdated: Date.now()
    };
  }

  updateContactInCache(pipelineId, contactId, attributeKey, newColumnValue) {
    if (!pipelineId || !this.cache[pipelineId]) return;

    const cachedData = this.cache[pipelineId];
    const contacts = [...cachedData.contacts];
    const contactIndex = contacts.findIndex(c => c.id === contactId);

    if (contactIndex !== -1) {
      contacts[contactIndex] = {
        ...contacts[contactIndex],
        custom_attributes: {
          ...contacts[contactIndex].custom_attributes,
          [attributeKey]: newColumnValue
        }
      };

      this.cache[pipelineId] = {
        ...cachedData,
        contacts,
        lastUpdated: Date.now()
      };

      // Atualizar o store para refletir a mudança imediatamente
      this.store.commit('contacts/SET_CONTACTS', contacts);
    }
  }

  getCache(pipelineId) {
    return this.cache[pipelineId];
  }

  clearCache(pipelineId) {
    if (pipelineId) {
      delete this.cache[pipelineId];
    } else {
      this.cache = {};
    }
  }
} 