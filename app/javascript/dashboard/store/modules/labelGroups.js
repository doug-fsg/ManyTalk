import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import LabelGroupsAPI from '../../api/labelGroups';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
  },
};

export const getters = {
  getLabelGroups(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getSidebarLabelSections(_state, _getters, _rootState, rootGetters) {
    const groups = [..._state.records].sort(
      (a, b) => a.position - b.position || a.name.localeCompare(b.name)
    );
    const sidebarLabels = rootGetters['labels/getLabelsOnSidebar'];

    if (!groups.length) {
      return { mode: 'flat', sections: [] };
    }

    const sections = groups
      .map(group => ({
        id: group.id,
        name: group.name,
        labels: sidebarLabels.filter(
          label => label.label_group_id === group.id
        ),
      }))
      .filter(section => section.labels.length);

    const ungrouped = sidebarLabels.filter(label => !label.label_group_id);
    if (ungrouped.length) {
      sections.push({
        id: 'ungrouped',
        name: null,
        labels: ungrouped,
      });
    }

    return { mode: 'grouped', sections };
  },
};

export const actions = {
  get: async function getLabelGroups({ commit }) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isFetching: true });
    try {
      const response = await LabelGroupsAPI.get();
      commit(types.SET_LABEL_GROUPS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createLabelGroup({ commit }, groupObj) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isCreating: true });
    try {
      const response = await LabelGroupsAPI.create(groupObj);
      commit(types.ADD_LABEL_GROUP, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateLabelGroup({ commit }, { id, ...updateObj }) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isUpdating: true });
    try {
      const response = await LabelGroupsAPI.update(id, updateObj);
      commit(types.EDIT_LABEL_GROUP, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteLabelGroup({ commit }, id) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isDeleting: true });
    try {
      await LabelGroupsAPI.delete(id);
      commit(types.DELETE_LABEL_GROUP, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_LABEL_GROUP_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_LABEL_GROUPS]: MutationHelpers.set,
  [types.ADD_LABEL_GROUP]: MutationHelpers.create,
  [types.EDIT_LABEL_GROUP]: MutationHelpers.update,
  [types.DELETE_LABEL_GROUP]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
