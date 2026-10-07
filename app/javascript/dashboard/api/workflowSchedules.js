/* global axios */
import ApiClient from './ApiClient';

class WorkflowSchedulesAPI extends ApiClient {
  constructor() {
    super('workflow_schedules', { accountScoped: true });
  }

  toggleActive(id) {
    return axios.post(`${this.url}/${id}/toggle_active`);
  }

  audienceCount({ pipelineId, stageId }) {
    return axios.get(`${this.url}/audience_count`, {
      params: { pipeline_id: pipelineId, stage_id: stageId },
    });
  }
}

export default new WorkflowSchedulesAPI();
