import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import WorkflowSchedulesAPI from '../../api/workflowSchedules';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
    fetchError: false,
  },
};

export const getters = {
  getSchedules(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getFetchError(_state) {
    return _state.uiFlags.fetchError;
  },
};

const payloadFrom = response => response.data.payload || response.data;

export const actions = {
  get: async function getSchedules({ commit }) {
    commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, {
      isFetching: true,
      fetchError: false,
    });
    try {
      const response = await WorkflowSchedulesAPI.get();
      commit(types.SET_WORKFLOW_SCHEDULES, response.data.payload || []);
    } catch (error) {
      commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { fetchError: true });
    } finally {
      commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createSchedule({ commit }, payload) {
    commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isCreating: true });
    try {
      const response = await WorkflowSchedulesAPI.create(payload);
      const record = payloadFrom(response);
      commit(types.ADD_WORKFLOW_SCHEDULE, record);
      return record;
    } finally {
      commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...payload }) => {
    commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isUpdating: true });
    try {
      const response = await WorkflowSchedulesAPI.update(id, payload);
      const record = payloadFrom(response);
      commit(types.EDIT_WORKFLOW_SCHEDULE, record);
      return record;
    } finally {
      commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isDeleting: true });
    try {
      await WorkflowSchedulesAPI.delete(id);
      commit(types.DELETE_WORKFLOW_SCHEDULE, id);
    } finally {
      commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isDeleting: false });
    }
  },
  toggleActive: async ({ commit }, id) => {
    commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isUpdating: true });
    try {
      const response = await WorkflowSchedulesAPI.toggleActive(id);
      commit(types.EDIT_WORKFLOW_SCHEDULE, payloadFrom(response));
    } catch (error) {
      const apiError = error?.response?.data?.error;
      const message = Array.isArray(apiError) ? apiError.join(', ') : apiError;
      throw new Error(message || error?.message || 'Unknown error');
    } finally {
      commit(types.SET_WORKFLOW_SCHEDULE_UI_FLAG, { isUpdating: false });
    }
  },
  audienceCount: async (_context, { pipelineId, stageId }) => {
    const response = await WorkflowSchedulesAPI.audienceCount({
      pipelineId,
      stageId,
    });
    return response.data.count ?? 0;
  },
};

export const mutations = {
  [types.SET_WORKFLOW_SCHEDULE_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.ADD_WORKFLOW_SCHEDULE]: MutationHelpers.create,
  [types.SET_WORKFLOW_SCHEDULES]: MutationHelpers.set,
  [types.EDIT_WORKFLOW_SCHEDULE]: MutationHelpers.update,
  [types.DELETE_WORKFLOW_SCHEDULE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
