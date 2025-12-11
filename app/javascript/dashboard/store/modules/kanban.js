import Vue from 'vue';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import AttributesAPI from '../../api/attributes';

const state = {
  myPermissions: {},
  uiFlags: {
    isFetchingPermissions: false,
  },
};

export const getters = {
  getMyPermissions: $state => $state.myPermissions,
  canEditPipeline: $state => pipelineId => {
    const permission = $state.myPermissions[pipelineId];
    return permission === 'admin' || permission === 'editor';
  },
  canViewPipeline: $state => pipelineId => {
    const permission = $state.myPermissions[pipelineId];
    return ['admin', 'editor', 'viewer'].includes(permission);
  },
  getPipelinePermission: $state => pipelineId => {
    return $state.myPermissions[pipelineId] || 'editor';
  },
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  fetchMyPermissions: async ({ commit }, accountId) => {
    commit('SET_PERMISSIONS_FETCHING_STATUS', true);
    try {
      // Buscar todos os custom attributes (pipelines Kanban)
      const response = await AttributesAPI.getAttributes(accountId, 'contact_attribute');
      
      // Extrair permissões de cada pipeline Kanban
      const permissions = {};
      response.data.forEach(attribute => {
        if (attribute.is_kanban) {
          // A permissão do usuário atual será determinada no backend
          // Por enquanto, assumir editor como padrão
          permissions[attribute.id] = 'editor';
        }
      });
      
      commit('SET_MY_PERMISSIONS', permissions);
      commit('SET_PERMISSIONS_FETCHING_STATUS', false);
    } catch (error) {
      commit('SET_PERMISSIONS_FETCHING_STATUS', false);
      throw error;
    }
  },
  
  updatePipelinePermission: ({ commit }, { pipelineId, permission }) => {
    commit('UPDATE_PIPELINE_PERMISSION', { pipelineId, permission });
  },
};

export const mutations = {
  SET_MY_PERMISSIONS($state, permissions) {
    Vue.set($state, 'myPermissions', permissions);
  },
  
  UPDATE_PIPELINE_PERMISSION($state, { pipelineId, permission }) {
    Vue.set($state.myPermissions, pipelineId, permission);
  },
  
  SET_PERMISSIONS_FETCHING_STATUS($state, status) {
    Vue.set($state.uiFlags, 'isFetchingPermissions', status);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

