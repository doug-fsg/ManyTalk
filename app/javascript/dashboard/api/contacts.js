/* global axios */
import ApiClient from './ApiClient';

export const buildContactParams = (page, sortAttr, label, search) => {
  let params = `include_contact_inboxes=false&page=${page}&sort=${sortAttr}`;
  if (search) {
    params = `${params}&q=${search}`;
  }
  if (label) {
    params = `${params}&labels[]=${label}`;
  }
  return params;
};

class ContactAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  get(page, sortAttr = 'name', label = '') {
    let requestURL = `${this.url}?${buildContactParams(
      page,
      sortAttr,
      label,
      ''
    )}`;
    return axios.get(requestURL);
  }

  getConversations(contactId) {
    return axios.get(`${this.url}/${contactId}/conversations`);
  }

  getContactableInboxes(contactId) {
    return axios.get(`${this.url}/${contactId}/contactable_inboxes`);
  }

  getContactLabels(contactId) {
    return axios.get(`${this.url}/${contactId}/labels`);
  }

  updateContactLabels(contactId, labels) {
    return axios.post(`${this.url}/${contactId}/labels`, { labels });
  }

  search(search = '', page = 1, sortAttr = 'name', label = '') {
    let requestURL = `${this.url}/search?${buildContactParams(
      page,
      sortAttr,
      label,
      search
    )}`;
    return axios.get(requestURL);
  }

  // eslint-disable-next-line default-param-last
  filter(page = 1, sortAttr = 'name', queryPayload) {
    let requestURL = `${this.url}/filter?${buildContactParams(page, sortAttr)}`;
    return axios.post(requestURL, queryPayload);
  }

  importContacts(file) {
    const formData = new FormData();
    formData.append('import_file', file);
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  destroyCustomAttributes(contactId, customAttributes) {
    return axios.post(`${this.url}/${contactId}/destroy_custom_attributes`, {
      custom_attributes: customAttributes,
    });
  }

  destroyAvatar(contactId) {
    return axios.delete(`${this.url}/${contactId}/avatar`);
  }

  exportContacts(queryPayload) {
    return axios.post(`${this.url}/export`, queryPayload);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  // Atualizar posição do contato no pipeline (apenas contact_pipeline_positions)
  // options: { updateAssignee: boolean, assigneeId: number|null }
  // Se updateAssignee for true, envia assignee_id na requisição (pode ser null para remover)
  // Se updateAssignee for false ou não fornecido, não altera o assignee
  updatePipelinePosition(contactId, pipelineId, stageId, position, enteredAt = null, dealValue = null, metadata = null, options = undefined) {
    const params = {
      stage_id: stageId,
      position: position,
    };
    if (enteredAt) {
      params.entered_at = enteredAt;
    }
    if (dealValue !== null && dealValue !== undefined) {
      params.deal_value = dealValue;
    }
    if (metadata !== null && metadata !== undefined) {
      params.metadata = metadata;
    }
    
    // Só enviar assignee_id se options foi fornecido E updateAssignee for true
    // Verificar se options foi realmente fornecido (não apenas undefined por padrão)
    const wasOptionsProvided = arguments.length >= 8 && options !== undefined;
    const willUpdateAssignee = wasOptionsProvided && options && options.updateAssignee === true;
    
    if (willUpdateAssignee) {
      params.assignee_id = options.assigneeId;
    }
    
    return axios.patch(`${this.url}/${contactId}/pipeline_positions/${pipelineId}`, params);
  }

  // Remover contato do pipeline
  deletePipelinePosition(contactId, pipelineId) {
    return axios.delete(`${this.url}/${contactId}/pipeline_positions/${pipelineId}`);
  }

  // Reordenar múltiplas posições de uma vez
  reorderPipelinePositions(pipelineId, positions) {
    const accountId = this.accountIdFromRoute;
    return axios.post(`/api/v1/accounts/${accountId}/contacts/pipeline_positions/reorder`, {
      pipeline_id: pipelineId,
      positions: positions,
    });
  }

  // Obter estatísticas agregadas por stage (totais reais)
  getPipelineStats(pipelineId) {
    return axios.get(`${this.url}/pipeline_positions/${pipelineId}/stats`);
  }

  // Obter estatísticas completas do dashboard (calculadas no banco)
  getDashboardStats(pipelineId) {
    return axios.get(`${this.url}/pipeline_positions/${pipelineId}/dashboard_stats`);
  }
}

export default new ContactAPI();