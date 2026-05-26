import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import WorkflowsAPI from '../../api/workflows';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
    isCloning: false,
  },
};

export const getters = {
  getWorkflows(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getWorkflow: _state => id => _state.records.find(r => r.id === Number(id)),
};

export const actions = {
  get: async function getWorkflows({ commit }) {
    commit(types.SET_WORKFLOW_UI_FLAG, { isFetching: true });
    try {
      const response = await WorkflowsAPI.get();
      commit(types.SET_WORKFLOWS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_WORKFLOW_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createWorkflow({ commit }, workflowObj) {
    commit(types.SET_WORKFLOW_UI_FLAG, { isCreating: true });
    try {
      const response = await WorkflowsAPI.create(workflowObj);
      commit(types.ADD_WORKFLOW, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_WORKFLOW_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_WORKFLOW_UI_FLAG, { isUpdating: true });
    try {
      const response = await WorkflowsAPI.update(id, updateObj);
      commit(types.EDIT_WORKFLOW, response.data.payload);
      return response.data.payload;
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_WORKFLOW_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_WORKFLOW_UI_FLAG, { isDeleting: true });
    try {
      await WorkflowsAPI.delete(id);
      commit(types.DELETE_WORKFLOW, id);
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_WORKFLOW_UI_FLAG, { isDeleting: false });
    }
  },
  clone: async ({ commit, dispatch }, id) => {
    commit(types.SET_WORKFLOW_UI_FLAG, { isCloning: true });
    try {
      await WorkflowsAPI.clone(id);
      await dispatch('get');
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_WORKFLOW_UI_FLAG, { isCloning: false });
    }
  },
  toggleActive: async ({ commit, dispatch }, id) => {
    commit(types.SET_WORKFLOW_UI_FLAG, { isUpdating: true });
    try {
      const response = await WorkflowsAPI.toggleActive(id);
      commit(types.EDIT_WORKFLOW, response.data.payload);
    } catch (error) {
      throw error;
    } finally {
      commit(types.SET_WORKFLOW_UI_FLAG, { isUpdating: false });
      await dispatch('get');
    }
  },
};

export const mutations = {
  [types.SET_WORKFLOW_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.ADD_WORKFLOW]: MutationHelpers.create,
  [types.SET_WORKFLOWS]: MutationHelpers.set,
  [types.EDIT_WORKFLOW]: MutationHelpers.update,
  [types.DELETE_WORKFLOW]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
