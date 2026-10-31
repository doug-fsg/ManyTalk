/* global axios */
import ApiClient from './ApiClient';

class AiAttendantAPI extends ApiClient {
  constructor() {
    super('ai_attendant_configs', { accountScoped: true });
  }

  test(id, message, history = []) {
    return axios.post(`${this.url}/${id}/test`, { message, history });
  }

  getUsage() {
    return axios.get(`${this.baseUrl()}/ai_usage`);
  }
}

export default new AiAttendantAPI();
