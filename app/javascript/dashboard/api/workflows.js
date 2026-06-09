/* global axios */
import ApiClient from './ApiClient';

class WorkflowsAPI extends ApiClient {
  constructor() {
    super('workflows', { accountScoped: true });
  }

  getTemplates() {
    return axios.get(`${this.url}/templates`);
  }

  createFromTemplate(templateKey) {
    return axios.post(`${this.url}/from_template`, { template_key: templateKey });
  }

  validate(graph) {
    return axios.post(`${this.url}/validate`, { graph });
  }

  clone(workflowId) {
    return axios.post(`${this.url}/${workflowId}/clone`);
  }

  toggleActive(workflowId) {
    return axios.post(`${this.url}/${workflowId}/toggle_active`);
  }

  testExternalWhatsapp({ inboxId, phoneNumber, message }) {
    return axios.post(`${this.url}/test_external_whatsapp`, {
      inbox_id: inboxId,
      phone_number: phoneNumber,
      message,
    });
  }
}

export default new WorkflowsAPI();
