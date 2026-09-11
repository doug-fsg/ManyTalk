import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import CustomRoleAPI from '../../api/customRole';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getCustomRoles: _state => _state.records,
  getUIFlags: _state => _state.uiFlags,
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isFetching: true });
    try {
      const response = await CustomRoleAPI.get();
      commit(types.SET_CUSTOM_ROLES, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ commit }, payload) => {
    commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isCreating: true });
    try {
      const response = await CustomRoleAPI.create(payload);
      commit(types.ADD_CUSTOM_ROLE, response.data);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...payload }) => {
    commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isUpdating: true });
    try {
      const response = await CustomRoleAPI.update(id, payload);
      commit(types.EDIT_CUSTOM_ROLE, response.data);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isDeleting: true });
    try {
      await CustomRoleAPI.delete(id);
      commit(types.DELETE_CUSTOM_ROLE, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_CUSTOM_ROLE_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CUSTOM_ROLE_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_CUSTOM_ROLES]: MutationHelpers.set,
  [types.ADD_CUSTOM_ROLE]: MutationHelpers.create,
  [types.EDIT_CUSTOM_ROLE]: MutationHelpers.update,
  [types.DELETE_CUSTOM_ROLE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
