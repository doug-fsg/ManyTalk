/* global axios */
import ApiClient from './ApiClient';

class AnnouncementsAPI extends ApiClient {
  constructor() {
    super('announcements', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(id, data) {
    return axios.put(`${this.url}/${id}`, data);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new AnnouncementsAPI();

