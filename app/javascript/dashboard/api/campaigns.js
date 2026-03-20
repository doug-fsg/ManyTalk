/* global axios */
import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  getProgress(id) {
    return axios.get(`${this.url}/${id}/progress`);
  }

  retryFailed(id, contacts = null) {
    const data = contacts ? { contacts } : {};
    return axios.post(`${this.url}/${id}/retry_failed`, data);
  }

  pause(id) {
    return axios.post(`${this.url}/${id}/pause`);
  }

  stop(id) {
    return axios.post(`${this.url}/${id}/stop`);
  }

  resume(id) {
    return axios.post(`${this.url}/${id}/resume`);
  }
}

export default new CampaignsAPI();
