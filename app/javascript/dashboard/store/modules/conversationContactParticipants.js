import types from '../mutation-types';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import ConversationInboxApi from '../../api/inbox/conversation';

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
  },
};

export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getByConversationId: _state => conversationId => {
    return _state.records[conversationId] || [];
  },
};

export const actions = {
  show: async ({ commit }, { conversationId }) => {
    commit(types.SET_CONVERSATION_CONTACT_PARTICIPANTS_UI_FLAG, {
      isFetching: true,
    });
    try {
      const response =
        await ConversationInboxApi.fetchContactParticipants(conversationId);
      commit(types.SET_CONVERSATION_CONTACT_PARTICIPANTS, {
        conversationId,
        data: response.data,
      });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_CONVERSATION_CONTACT_PARTICIPANTS_UI_FLAG, {
        isFetching: false,
      });
    }
  },
};

export const mutations = {
  [types.SET_CONVERSATION_CONTACT_PARTICIPANTS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.SET_CONVERSATION_CONTACT_PARTICIPANTS](
    $state,
    { data, conversationId }
  ) {
    $state.records = {
      ...$state.records,
      [conversationId]: data,
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
