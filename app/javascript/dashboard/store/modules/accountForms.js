import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import AccountFormsAPI from '../../api/accountForms';

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
  getAccountForms(_state) {
    return _state.records;
  },
  getAccountFormUIFlags(_state) {
    return _state.uiFlags;
  },
  getAccountForm: _state => id =>
    _state.records.find(record => record.id === Number(id)),
};

export const actions = {
  show: async function showAccountForm({ commit }, id) {
    try {
      const response = await AccountFormsAPI.show(id);
      commit(types.EDIT_ACCOUNT_FORM, response.data);
      return response.data;
    } catch {
      // ignore — caller handles missing form
    }
  },

  get: async function getAccountForms({ commit }) {
    commit(types.SET_ACCOUNT_FORM_UI_FLAG, {
      isFetching: true,
      fetchError: false,
    });
    try {
      const response = await AccountFormsAPI.get();
      commit(types.SET_ACCOUNT_FORMS, response.data.payload);
    } catch {
      commit(types.SET_ACCOUNT_FORM_UI_FLAG, { fetchError: true });
    } finally {
      commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createAccountForm({ commit }, formObj) {
    commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isCreating: true });
    try {
      const response = await AccountFormsAPI.create(formObj);
      commit(types.ADD_ACCOUNT_FORM, response.data);
      return response.data;
    } finally {
      commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isUpdating: true });
    try {
      const response = await AccountFormsAPI.update(id, updateObj);
      commit(types.EDIT_ACCOUNT_FORM, response.data);
      return response.data;
    } finally {
      commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isUpdating: false });
    }
  },

  updateStatus: async ({ commit }, { id, status }) => {
    commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isUpdating: true });
    try {
      const response = await AccountFormsAPI.updateStatus(id, status);
      commit(types.EDIT_ACCOUNT_FORM, response.data);
      return response.data;
    } finally {
      commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isDeleting: true });
    try {
      await AccountFormsAPI.delete(id);
      commit(types.DELETE_ACCOUNT_FORM, id);
    } finally {
      commit(types.SET_ACCOUNT_FORM_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_ACCOUNT_FORM_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_ACCOUNT_FORMS](_state, data) {
    _state.records = data;
  },
  [types.ADD_ACCOUNT_FORM](_state, data) {
    _state.records.unshift(data);
  },
  [types.EDIT_ACCOUNT_FORM](_state, data) {
    MutationHelpers.updateAttributes(_state.records, data.id, data);
  },
  [types.DELETE_ACCOUNT_FORM](_state, id) {
    _state.records = _state.records.filter(record => record.id !== Number(id));
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
