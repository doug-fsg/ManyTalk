/* global axios */
import ApiClient from './ApiClient';

class WorkflowsAPI extends ApiClient {
  constructor() {
    super('workflows', { accountScoped: true });
  }

  clone(workflowId) {
    return axios.post(`${this.url}/${workflowId}/clone`);
  }

  toggleActive(workflowId) {
    return axios.post(`${this.url}/${workflowId}/toggle_active`);
  }
}

export default new WorkflowsAPI();
