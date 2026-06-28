/* global axios */
import ApiClient from './ApiClient';

class AccountFormsAPI extends ApiClient {
  constructor() {
    super('account_forms', { accountScoped: true });
  }

  updateStatus(formId, status) {
    return axios.post(`${this.url}/${formId}/update_status`, { status });
  }

  getSubmissions(formId, { page = 1, perPage = 25 } = {}) {
    return axios.get(`${this.url}/${formId}/submissions`, {
      params: { page, per_page: perPage },
    });
  }

  exportSubmissions(formId) {
    return axios.get(`${this.url}/${formId}/export_submissions`, {
      responseType: 'blob',
    });
  }
}

export default new AccountFormsAPI();
