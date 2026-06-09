/* global axios */
import ApiClient from './ApiClient';

class ConversationWorkflowEnrollmentsAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  basePath(conversationId) {
    return `${this.baseUrl()}/conversations/${conversationId}/workflow_enrollments`;
  }

  getActive(conversationId) {
    return axios.get(`${this.basePath(conversationId)}/active`);
  }

  start(conversationId, { workflowId, startNodeId }) {
    return axios.post(this.basePath(conversationId), {
      workflow_id: workflowId,
      start_node_id: startNodeId,
    });
  }

  pause(conversationId, enrollmentId) {
    return axios.post(
      `${this.basePath(conversationId)}/${enrollmentId}/pause`
    );
  }

  resume(conversationId, enrollmentId) {
    return axios.post(
      `${this.basePath(conversationId)}/${enrollmentId}/resume`
    );
  }

  cancel(conversationId, enrollmentId) {
    return axios.post(
      `${this.basePath(conversationId)}/${enrollmentId}/cancel`
    );
  }

  jump(conversationId, enrollmentId, nodeId) {
    return axios.post(
      `${this.basePath(conversationId)}/${enrollmentId}/jump`,
      { node_id: nodeId }
    );
  }

  rebind(conversationId, enrollmentId, targetConversationId) {
    return axios.post(
      `${this.basePath(conversationId)}/${enrollmentId}/rebind`,
      { conversation_id: targetConversationId }
    );
  }
}

export default new ConversationWorkflowEnrollmentsAPI();
