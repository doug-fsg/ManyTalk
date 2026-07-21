/* global axios */
import ApiClient from './ApiClient';

class ContactTimelineAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  get(contactId, params = {}) {
    return axios.get(`${this.url}/${contactId}/timeline`, { params });
  }
}

export default new ContactTimelineAPI();
