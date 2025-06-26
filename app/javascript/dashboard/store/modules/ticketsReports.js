import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import TicketsReportsAPI from '../../api/ticketsReports';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';

export const state = {
  records: [],
  metrics: {
    totalTickets: 0,
    avgResolutionTime: 0,
    escalationPercentage: 0,
    resolvedAfterEscalation: 0,
  },
  uiFlags: {
    isFetching: false,
    isFetchingMetrics: false,
  },
  meta: {
    count: 0,
    current_page: 1,
    per_page: 25,
    total_pages: 0,
    total_count: 0,
  },
};

export const getters = {
  getAll(_state) {
    return _state.records;
  },
  getMeta(_state) {
    return _state.meta;
  },
  getMetrics(_state) {
    return _state.metrics;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getTicketsReports({ commit }, params) {
    commit(types.SET_TICKETS_REPORTS_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketsReportsAPI.get(params);
      
      // Handle response format based on backend structure
      let tickets, meta, metrics;
      
      if (response.data.tickets) {
        // New backend structure: { tickets: [...], metrics: {...} }
        tickets = response.data.tickets;
        metrics = response.data.metrics;
        meta = {
          count: tickets.length,
          current_page: parseInt(response.headers['x-current-page'], 10) || 1,
          per_page: parseInt(response.headers['x-per-page'], 10) || 25,
          total_pages: parseInt(response.headers['x-total-pages'], 10) || 1,
          total_count: parseInt(response.headers['x-total-count'], 10) || 0,
        };
      } else if (Array.isArray(response.data)) {
        // Direct array response
        tickets = response.data;
        meta = {
          count: tickets.length,
          current_page: parseInt(response.headers['x-current-page'], 10) || 1,
          per_page: parseInt(response.headers['x-per-page'], 10) || 25,
          total_pages: parseInt(response.headers['x-total-pages'], 10) || 1,
          total_count: parseInt(response.headers['x-total-count'], 10) || 0,
        };
      } else {
        // Legacy structure with payload
        tickets = response.data.payload || response.data;
        meta = response.data.meta || {};
      }

      commit(types.SET_TICKETS_REPORTS, tickets);
      commit(types.SET_TICKETS_REPORTS_META, meta);
      
      // Set metrics if available
      if (metrics) {
        commit(types.SET_TICKETS_REPORTS_METRICS, metrics);
      }
    } catch (error) {
      console.error('Error fetching tickets reports:', error);
      throw new Error(error);
    } finally {
      commit(types.SET_TICKETS_REPORTS_UI_FLAG, { isFetching: false });
    }
  },
  
  getMetrics: async function getTicketsMetrics({ commit }, params) {
    commit(types.SET_TICKETS_REPORTS_UI_FLAG, { isFetchingMetrics: true });
    try {
      const response = await TicketsReportsAPI.getMetrics(params);
      commit(types.SET_TICKETS_REPORTS_METRICS, response.data);
    } catch (error) {
      console.error('Error fetching tickets metrics:', error);
    } finally {
      commit(types.SET_TICKETS_REPORTS_UI_FLAG, { isFetchingMetrics: false });
    }
  },
  
  download(_, params) {
    return TicketsReportsAPI.download(params).then(response => {
      downloadCsvFile(params.fileName, response.data);
    });
  },
};

export const mutations = {
  [types.SET_TICKETS_REPORTS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_TICKETS_REPORTS]: MutationHelpers.set,
  
  [types.SET_TICKETS_REPORTS_METRICS](
    _state,
    {
      total_tickets: totalTickets,
      avg_resolution_time: avgResolutionTime,
      escalation_percentage: escalationPercentage,
      resolved_after_escalation: resolvedAfterEscalation,
    }
  ) {
    _state.metrics = {
      totalTickets: totalTickets || 0,
      avgResolutionTime: avgResolutionTime || 0,
      escalationPercentage: escalationPercentage || 0,
      resolvedAfterEscalation: resolvedAfterEscalation || 0,
    };
  },
  
  [types.SET_TICKETS_REPORTS_META](_state, meta) {
    _state.meta = {
      count: meta.count || 0,
      current_page: meta.current_page || 1,
      per_page: meta.per_page || 25,
      total_pages: meta.total_pages || 0,
      total_count: meta.total_count || 0,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
