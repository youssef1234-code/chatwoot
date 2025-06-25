import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import NPSReports from '../../api/npsReports';
import { downloadCsvFile } from '../../helper/downloadHelper';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { REPORTS_EVENTS } from '../../helper/AnalyticsHelper/events';

const computeDistribution = (value, total) =>
  ((value * 100) / total).toFixed(2);

export const state = {
  records: [],
  metrics: {
    totalResponseCount: 0,
    ratingsCount: {
      0: 0,
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
      8: 0,
      9: 0,
      10: 0,
    },
    totalSentMessagesCount: 0,
  },
  uiFlags: {
    isFetching: false,
    isFetchingMetrics: false,
  },
};

export const getters = {
  getNPSResponses(_state) {
    return _state.records;
  },
  getMetrics(_state) {
    return _state.metrics;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getNetPromoterScore(_state) {
    if (!_state.metrics.totalResponseCount) {
      return 0;
    }
    // Promoters (9-10) - Detractors (0-6)
    const promoters = _state.metrics.ratingsCount[9] + _state.metrics.ratingsCount[10];
    const detractors = _state.metrics.ratingsCount[0] + _state.metrics.ratingsCount[1] + 
                      _state.metrics.ratingsCount[2] + _state.metrics.ratingsCount[3] + 
                      _state.metrics.ratingsCount[4] + _state.metrics.ratingsCount[5] + 
                      _state.metrics.ratingsCount[6];
    
    return computeDistribution(
      promoters - detractors,
      _state.metrics.totalResponseCount
    );
  },
  getResponseRate(_state) {
    if (!_state.metrics.totalSentMessagesCount) {
      return 0;
    }
    return computeDistribution(
      _state.metrics.totalResponseCount,
      _state.metrics.totalSentMessagesCount
    );
  },
  getRatingPercentage(_state) {
    if (!_state.metrics.totalResponseCount) {
      return { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0 };
    }
    return {
      0: computeDistribution(_state.metrics.ratingsCount[0], _state.metrics.totalResponseCount),
      1: computeDistribution(_state.metrics.ratingsCount[1], _state.metrics.totalResponseCount),
      2: computeDistribution(_state.metrics.ratingsCount[2], _state.metrics.totalResponseCount),
      3: computeDistribution(_state.metrics.ratingsCount[3], _state.metrics.totalResponseCount),
      4: computeDistribution(_state.metrics.ratingsCount[4], _state.metrics.totalResponseCount),
      5: computeDistribution(_state.metrics.ratingsCount[5], _state.metrics.totalResponseCount),
      6: computeDistribution(_state.metrics.ratingsCount[6], _state.metrics.totalResponseCount),
      7: computeDistribution(_state.metrics.ratingsCount[7], _state.metrics.totalResponseCount),
      8: computeDistribution(_state.metrics.ratingsCount[8], _state.metrics.totalResponseCount),
      9: computeDistribution(_state.metrics.ratingsCount[9], _state.metrics.totalResponseCount),
      10: computeDistribution(_state.metrics.ratingsCount[10], _state.metrics.totalResponseCount),
    };
  },
  getPromoterPercentage(_state) {
    if (!_state.metrics.totalResponseCount) {
      return 0;
    }
    const promoters = _state.metrics.ratingsCount[9] + _state.metrics.ratingsCount[10];
    return computeDistribution(promoters, _state.metrics.totalResponseCount);
  },
  getPassivePercentage(_state) {
    if (!_state.metrics.totalResponseCount) {
      return 0;
    }
    const passives = _state.metrics.ratingsCount[7] + _state.metrics.ratingsCount[8];
    return computeDistribution(passives, _state.metrics.totalResponseCount);
  },
  getDetractorPercentage(_state) {
    if (!_state.metrics.totalResponseCount) {
      return 0;
    }
    const detractors = _state.metrics.ratingsCount[0] + _state.metrics.ratingsCount[1] + 
                      _state.metrics.ratingsCount[2] + _state.metrics.ratingsCount[3] + 
                      _state.metrics.ratingsCount[4] + _state.metrics.ratingsCount[5] + 
                      _state.metrics.ratingsCount[6];
    return computeDistribution(detractors, _state.metrics.totalResponseCount);
  },
};

export const actions = {
  get: async function getResponses({ commit }, params) {
    commit(types.SET_NPS_RESPONSE_UI_FLAG, { isFetching: true });
    try {
      const response = await NPSReports.get(params);
      commit(types.SET_NPS_RESPONSE, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_NPS_RESPONSE_UI_FLAG, { isFetching: false });
    }
  },
  getMetrics: async function getMetrics({ commit }, params) {
    commit(types.SET_NPS_RESPONSE_UI_FLAG, { isFetchingMetrics: true });
    try {
      const response = await NPSReports.getMetrics(params);
      commit(types.SET_NPS_RESPONSE_METRICS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_NPS_RESPONSE_UI_FLAG, { isFetchingMetrics: false });
    }
  },
  downloadNPSReports(_, params) {
    return NPSReports.download(params).then(response => {
      downloadCsvFile(params.fileName, response.data);
      AnalyticsHelper.track(REPORTS_EVENTS.DOWNLOAD_REPORT, {
        reportType: 'nps',
      });
    });
  },
};

export const mutations = {
  [types.SET_NPS_RESPONSE_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_NPS_RESPONSE]: MutationHelpers.set,
  [types.SET_NPS_RESPONSE_METRICS](
    _state,
    {
      total_count: totalResponseCount,
      ratings_count: ratingsCount,
      total_sent_messages_count: totalSentMessagesCount,
    }
  ) {
    _state.metrics.totalResponseCount = totalResponseCount || 0;
    _state.metrics.ratingsCount = {
      0: ratingsCount['0'] || 0,
      1: ratingsCount['1'] || 0,
      2: ratingsCount['2'] || 0,
      3: ratingsCount['3'] || 0,
      4: ratingsCount['4'] || 0,
      5: ratingsCount['5'] || 0,
      6: ratingsCount['6'] || 0,
      7: ratingsCount['7'] || 0,
      8: ratingsCount['8'] || 0,
      9: ratingsCount['9'] || 0,
      10: ratingsCount['10'] || 0,
    };
    _state.metrics.totalSentMessagesCount = totalSentMessagesCount || 0;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
