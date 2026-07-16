import ActivitiesAPI from 'dashboard/api/activities';

const state = {
  records: [],
  meta: {
    count: 0,
    currentPage: 1,
    totalPages: 1,
  },
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

const getters = {
  getActivities: state => state.records,
  getActivitiesMeta: state => state.meta,
  getPendingActivities: state => state.records.filter(a => a.status === 'pending'),
  getActivitiesByStatus: state => status => state.records.filter(a => a.status === status),
  getPendingCountByContactId: (state) => {
    const map = {};
    state.records.forEach(a => {
      if (a.status !== 'pending') return;
      const cid = a.contact_id ?? a.contact?.id;
      if (cid != null) {
        map[cid] = (map[cid] || 0) + 1;
      }
    });
    return contactId => map[contactId] || 0;
  },
  getNextActivityByContactId: (state) => {
    const map = {};
    const pending = state.records.filter(a => a.status === 'pending');
    pending.forEach(a => {
      const cid = a.contact_id ?? a.contact?.id;
      if (cid != null) {
        const existing = map[cid];
        const aDate = new Date(a.scheduled_at);
        if (!existing || new Date(existing.scheduled_at) > aDate) {
          map[cid] = a;
        }
      }
    });
    return contactId => map[contactId] || null;
  },
};

const parseActivitiesResponse = data => {
  const defaultMeta = { count: 0, currentPage: 1, totalPages: 1 };
  if (Array.isArray(data)) {
    return { records: data, meta: { ...defaultMeta, count: data.length } };
  }
  return {
    records: data?.payload ?? data?.data ?? [],
    meta: {
      count: data?.meta?.count ?? 0,
      currentPage: data?.meta?.current_page ?? 1,
      totalPages: data?.meta?.total_pages ?? 1,
    },
  };
};

const actions = {
  async get({ commit }, { params = {}, merge = false } = {}) {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const { data } = await ActivitiesAPI.get(params);
      const { records, meta } = parseActivitiesResponse(data);
      if (merge) {
        commit('MERGE_ACTIVITIES', records);
      } else {
        commit('SET_ACTIVITIES', records);
      }
      commit('SET_META', meta);
      return { records, meta };
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },

  async create({ commit }, { params }) {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const { data } = await ActivitiesAPI.create(params);
      commit('ADD_ACTIVITY', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },

  async update({ commit }, { activityId, params }) {
    const { data } = await ActivitiesAPI.update(activityId, params);
    commit('UPDATE_ACTIVITY', data);
    return data;
  },

  async complete({ commit }, { activityId }) {
    const { data } = await ActivitiesAPI.complete(activityId);
    commit('UPDATE_ACTIVITY', data);
    return data;
  },

  async destroy({ commit }, { activityId }) {
    await ActivitiesAPI.destroy(activityId);
    commit('REMOVE_ACTIVITY', activityId);
  },
};

const mutations = {
  SET_ACTIVITIES(state, activities) {
    state.records = Array.isArray(activities) ? activities : [];
  },
  MERGE_ACTIVITIES(state, activities) {
    const records = Array.isArray(activities) ? activities : [];
    const existingIds = new Set(state.records.map(a => a.id));
    const newActivities = records.filter(a => !existingIds.has(a.id));
    state.records.push(...newActivities);
  },
  SET_META(state, meta) {
    state.meta = { ...state.meta, ...meta };
  },
  ADD_ACTIVITY(state, activity) {
    state.records.unshift(activity);
  },
  UPDATE_ACTIVITY(state, activity) {
    const index = state.records.findIndex(a => a.id === activity.id);
    if (index !== -1) {
      state.records.splice(index, 1, activity);
    } else {
      state.records.unshift(activity);
    }
  },
  REMOVE_ACTIVITY(state, activityId) {
    state.records = state.records.filter(a => a.id !== activityId);
  },
  SET_UI_FLAG(state, flags) {
    state.uiFlags = { ...state.uiFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
