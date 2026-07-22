/* global axios */
import ApiClient from './ApiClient';

class InboxHealthAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  getHealthStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/health`);
  }

  getPricingSummary(inboxId) {
    return axios.get(`${this.url}/${inboxId}/pricing`);
  }

  registerWebhook(inboxId) {
    return axios.post(`${this.url}/${inboxId}/register_webhook`);
  }
}

export default new InboxHealthAPI();
