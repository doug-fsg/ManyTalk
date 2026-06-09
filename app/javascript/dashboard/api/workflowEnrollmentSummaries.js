/* global axios */
import ApiClient from './ApiClient';

class WorkflowEnrollmentSummariesAPI extends ApiClient {
  constructor() {
    super('workflow_enrollment_summaries', { accountScoped: true });
  }

  getSummaries(conversationIds) {
    return axios.get(this.url, {
      params: {
        conversation_ids: conversationIds,
      },
      paramsSerializer: params => {
        const searchParams = new URLSearchParams();
        (params.conversation_ids || []).forEach(id => {
          searchParams.append('conversation_ids[]', id);
        });
        return searchParams.toString();
      },
    });
  }
}

export default new WorkflowEnrollmentSummariesAPI();
