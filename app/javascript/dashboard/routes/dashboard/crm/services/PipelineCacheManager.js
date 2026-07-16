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
      lastUpdated: Date.now(),
    };
  }

  updateContactInCache(pipelineId, contactId, stageId) {
    if (!pipelineId || !this.cache[pipelineId]) return;

    const cachedData = this.cache[pipelineId];
    const contacts = [...cachedData.contacts];
    const contactIndex = contacts.findIndex(c => c.id === contactId);

    if (contactIndex === -1) return;

    const contact = { ...contacts[contactIndex] };
    const pipelinePositions = [...(contact.pipeline_positions || [])];
    const positionIndex = pipelinePositions.findIndex(
      p => p.pipeline_id === pipelineId || p.pipeline_id === parseInt(pipelineId, 10)
    );

    const currentPosition = positionIndex >= 0 ? pipelinePositions[positionIndex] : null;
    const updatedPosition = {
      pipeline_id: pipelineId,
      stage_id: stageId,
      position: currentPosition?.position || 0,
      entered_at: currentPosition?.entered_at || new Date().toISOString(),
      deal_value: currentPosition?.deal_value ?? null,
      metadata: currentPosition?.metadata || {},
      assignee: currentPosition?.assignee || null,
    };

    if (positionIndex >= 0) {
      pipelinePositions[positionIndex] = updatedPosition;
    } else {
      pipelinePositions.push(updatedPosition);
    }

    contact.pipeline_positions = pipelinePositions;
    contacts[contactIndex] = contact;

    this.cache[pipelineId] = {
      ...cachedData,
      contacts,
      lastUpdated: Date.now(),
    };

    this.store.commit('contacts/SET_CONTACTS', contacts);
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
