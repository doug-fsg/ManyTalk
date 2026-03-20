import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import CampaignsAPI from '../../api/campaigns';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { CAMPAIGNS_EVENTS } from '../../helper/AnalyticsHelper/events';

export const state = {
  records: [],
  meta: {
    count: 0,
    current_page: 1,
    total_pages: 0,
  },
  progress: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getCampaigns: _state => campaignType => {
    return _state.records
      .filter(record => record.campaign_type === campaignType)
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  },
  getAllCampaigns: _state => {
    return _state.records;
  },
  getCampaignProgress: _state => campaignId => {
    return _state.progress[campaignId] || null;
  },
  getCampaignsMeta: _state => _state.meta,
};

export const actions = {
  get: async function getCampaigns({ commit }, params = {}) {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isFetching: true });
    try {
      const response = await CampaignsAPI.get(params);
      const { payload, meta } = response.data;
      const records = payload ?? (Array.isArray(response.data) ? response.data : []);
      commit(types.SET_CAMPAIGNS, records);
      if (meta) {
        commit(types.SET_CAMPAIGNS_META, meta);
      }
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createCampaign({ commit }, campaignObj) {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isCreating: true });
    try {
      const response = await CampaignsAPI.create(campaignObj);
      commit(types.ADD_CAMPAIGN, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isUpdating: true });
    try {
      const response = await CampaignsAPI.update(id, updateObj);
      AnalyticsHelper.track(CAMPAIGNS_EVENTS.UPDATE_CAMPAIGN);
      commit(types.EDIT_CAMPAIGN, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isDeleting: true });
    try {
      await CampaignsAPI.delete(id);
      AnalyticsHelper.track(CAMPAIGNS_EVENTS.DELETE_CAMPAIGN);
      commit(types.DELETE_CAMPAIGN, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isDeleting: false });
    }
  },
  fetchProgress: async ({ commit }, campaignId) => {
    try {
      const response = await CampaignsAPI.getProgress(campaignId);
      commit(types.UPDATE_CAMPAIGN_PROGRESS, response.data);
    } catch (error) {
      // Ignore silently
    }
  },
  retryFailed: async ({ commit }, { id, contacts }) => {
    try {
      await CampaignsAPI.retryFailed(id, contacts || null);
      commit(types.UPDATE_CAMPAIGN_PROGRESS, { campaign_id: id, status: 'processing' });
    } catch (error) {
      throw new Error(error);
    }
  },
  pause: async ({ commit }, id) => {
    try {
      const response = await CampaignsAPI.pause(id);
      commit(types.EDIT_CAMPAIGN, response.data.campaign);
      commit(types.UPDATE_CAMPAIGN_PROGRESS, { campaign_id: id, status: 'paused' });
    } catch (error) {
      throw new Error(error);
    }
  },
  stop: async ({ commit }, id) => {
    try {
      const response = await CampaignsAPI.stop(id);
      commit(types.EDIT_CAMPAIGN, response.data.campaign);
      commit(types.UPDATE_CAMPAIGN_PROGRESS, { campaign_id: id, status: 'stopped' });
    } catch (error) {
      throw new Error(error);
    }
  },
  resume: async ({ commit }, id) => {
    try {
      const response = await CampaignsAPI.resume(id);
      commit(types.EDIT_CAMPAIGN, response.data.campaign);
      commit(types.UPDATE_CAMPAIGN_PROGRESS, { campaign_id: id, status: 'processing' });
    } catch (error) {
      throw new Error(error);
    }
  },
};

export const mutations = {
  [types.SET_CAMPAIGN_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.ADD_CAMPAIGN]: MutationHelpers.create,
  [types.SET_CAMPAIGNS]: MutationHelpers.set,
  [types.SET_CAMPAIGNS_META](_state, data) {
    _state.meta = { ..._state.meta, ...data };
  },
  [types.EDIT_CAMPAIGN]: MutationHelpers.update,
  [types.DELETE_CAMPAIGN]: MutationHelpers.destroy,

  [types.UPDATE_CAMPAIGN_PROGRESS](_state, data) {
    const { campaign_id: campaignId, status, ...rest } = data;
    _state.progress = {
      ..._state.progress,
      [campaignId]: { ...(_state.progress[campaignId] || {}), status, ...rest },
    };

    const record = _state.records.find(r => r.id === campaignId);
    if (record && status) {
      record.campaign_status = status;
    }
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
