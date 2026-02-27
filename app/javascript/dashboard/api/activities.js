/* global axios */
import ApiClient from './ApiClient';

class ActivitiesAPI extends ApiClient {
  constructor() {
    super('activities', { accountScoped: true });
  }

  get(params = {}) {
    // contact_ids como array: Rails aceita contact_ids[]=1&contact_ids[]=2
    if (Array.isArray(params.contact_ids) && params.contact_ids.length > 0) {
      const { contact_ids, ...rest } = params;
      const searchParams = new URLSearchParams(rest);
      contact_ids.forEach(id => searchParams.append('contact_ids[]', id));
      return axios.get(`${this.url}?${searchParams.toString()}`);
    }
    return axios.get(this.url, { params });
  }

  show(activityId) {
    return axios.get(`${this.url}/${activityId}`);
  }

  create(params) {
    return axios.post(this.url, { activity: params });
  }

  update(activityId, params) {
    return axios.patch(`${this.url}/${activityId}`, { activity: params });
  }

  destroy(activityId) {
    return axios.delete(`${this.url}/${activityId}`);
  }

  complete(activityId) {
    return axios.post(`${this.url}/${activityId}/complete`);
  }
}

export default new ActivitiesAPI();

