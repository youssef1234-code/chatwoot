import TicketsAPI from '../../api/tickets';
import types from '../mutation-types';

export const state = {
  records: {},
  conversationTickets: {}, // tickets grouped by conversation_id
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
  meta: {
    total: 0,
    currentPage: 1,
    perPage: 25,
  },
};

export const getters = {
  getTickets: $state => Object.values($state.records),
  getTicket: $state => ticketId => $state.records[ticketId],
  getTicketsForConversation: $state => conversationId => 
    $state.conversationTickets[conversationId] || [],
  getUIFlags: $state => $state.uiFlags,
  getMeta: $state => $state.meta,
  getTotalCount: $state => $state.meta.total,
};

export const actions = {
  async fetch({ commit }, params = {}) {
    commit(types.SET_TICKETS_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketsAPI.getAll(params);
      commit(types.SET_TICKETS, response.data);
      commit(types.SET_TICKETS_META, {
        total: response.headers['x-total-count'] || response.data.length,
        currentPage: params.page || 1,
        perPage: params.per_page || 25,
      });
    } catch (error) {
      console.error('Error fetching tickets:', error);
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetching: false });
    }
  },

  async fetchTicket({ commit }, ticketId) {
    commit(types.SET_TICKETS_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketsAPI.get(ticketId);
      commit(types.SET_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error fetching ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetching: false });
    }
  },

  async fetchTicketsForConversation({ commit }, conversationId) {
    commit(types.SET_TICKETS_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketsAPI.getForConversation(conversationId);
      commit(types.SET_CONVERSATION_TICKETS, { 
        conversationId, 
        tickets: response.data 
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching tickets for conversation:', error);
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetching: false });
    }
  },

  async create({ commit }, ticketData) {
    commit(types.SET_TICKETS_UI_FLAG, { isCreating: true });
    try {
      const response = await TicketsAPI.create(ticketData);
      commit(types.ADD_TICKET, response.data);
      commit(types.ADD_TICKET_TO_CONVERSATION, {
        conversationId: response.data.conversation.id,
        ticket: response.data,
      });
      return response.data;
    } catch (error) {
      console.error('Error creating ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isCreating: false });
    }
  },

  async update({ commit }, { ticketId, ...ticketData }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.update(ticketId, ticketData);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error updating ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  // Convenience method for updating tickets with id in the data
  async updateTicket({ commit }, { id, ...ticketData }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.update(id, ticketData);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error updating ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  async delete({ commit }, ticketId) {
    commit(types.SET_TICKETS_UI_FLAG, { isDeleting: true });
    try {
      await TicketsAPI.delete(ticketId);
      commit(types.DELETE_TICKET, ticketId);
      return true;
    } catch (error) {
      console.error('Error deleting ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isDeleting: false });
    }
  },

  async escalateToJira({ commit }, { ticketId, jiraIssueKey }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.escalateToJira(ticketId, jiraIssueKey);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error escalating ticket to JIRA:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  async resolve({ commit }, ticketId) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.resolve(ticketId);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error resolving ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  async close({ commit }, ticketId) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.close(ticketId);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error closing ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  async addMessages({ commit }, { ticketId, messageIds }) {
    try {
      const response = await TicketsAPI.addMessages(ticketId, { message_ids: messageIds });
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error adding messages to ticket:', error);
      throw error;
    }
  },

  async removeMessages({ commit }, { ticketId, messageIds }) {
    try {
      const response = await TicketsAPI.removeMessages(ticketId, { message_ids: messageIds });
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error removing messages from ticket:', error);
      throw error;
    }
  },

  // WebSocket action for real-time ticket updates
  updateTicketFromWebSocket({ commit, state }, ticketData) {
    console.log('Tickets Store: Updating ticket from WebSocket', ticketData);
    
    // Check if this ticket exists in our store
    const existingTicket = state.records[ticketData.ticket_id];
    
    if (existingTicket) {
      // Create updated ticket object
      const updatedTicket = {
        ...existingTicket,
        status: ticketData.status,
        resolved_at: ticketData.resolved_at,
        // Preserve other fields that might not be in the WebSocket data
      };
      
      commit(types.UPDATE_TICKET, updatedTicket);
      console.log('Tickets Store: Ticket updated via WebSocket');
    } else {
      console.log('Tickets Store: Ticket not found in store, ignoring WebSocket update');
    }
  },
};

export const mutations = {
  [types.SET_TICKETS_UI_FLAG]($state, data) {
    Object.assign($state.uiFlags, data);
  },

  [types.SET_TICKETS]($state, tickets) {
    $state.records = tickets.reduce((acc, ticket) => {
      acc[ticket.id] = ticket;
      return acc;
    }, {});
  },

  [types.SET_TICKET]($state, ticket) {
    $state.records[ticket.id] = ticket;
  },

  [types.ADD_TICKET]($state, ticket) {
    $state.records[ticket.id] = ticket;
    $state.meta.total += 1;
  },

  [types.UPDATE_TICKET]($state, ticket) {
    $state.records[ticket.id] = ticket;
  },

  [types.DELETE_TICKET]($state, ticketId) {
    delete $state.records[ticketId];
    $state.meta.total -= 1;
    
    // Remove from conversation tickets as well
    Object.keys($state.conversationTickets).forEach(conversationId => {
      $state.conversationTickets[conversationId] = 
        $state.conversationTickets[conversationId].filter(ticket => ticket.id !== ticketId);
    });
  },

  [types.SET_CONVERSATION_TICKETS]($state, { conversationId, tickets }) {
    $state.conversationTickets[conversationId] = tickets;
    
    // Also add to main records
    tickets.forEach(ticket => {
      $state.records[ticket.id] = ticket;
    });
  },

  [types.ADD_TICKET_TO_CONVERSATION]($state, { conversationId, ticket }) {
    if (!$state.conversationTickets[conversationId]) {
      $state.conversationTickets[conversationId] = [];
    }
    
    // Check if ticket already exists in conversation
    const existingIndex = $state.conversationTickets[conversationId]
      .findIndex(t => t.id === ticket.id);
    
    if (existingIndex >= 0) {
      $state.conversationTickets[conversationId][existingIndex] = ticket;
    } else {
      $state.conversationTickets[conversationId].push(ticket);
    }
  },

  [types.SET_TICKETS_META]($state, meta) {
    Object.assign($state.meta, meta);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
