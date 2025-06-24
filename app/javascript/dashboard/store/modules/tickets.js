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
      
      // Try to get total count from headers, fallback to response data length
      const totalCount = parseInt(response.headers['X-Total-Count'] || response.headers['x-total-count'] || response.data.length, 10);
      
      commit(types.SET_TICKETS_META, {
        total: totalCount,
        currentPage: parseInt(params.page || 1, 10),
        perPage: parseInt(params.per_page || 25, 10),
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching tickets:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetching: false });
    }
  },

  async fetchTickets({ commit }, params = {}) {
    commit(types.SET_TICKETS_UI_FLAG, { isFetching: true });
    try {
      const response = await TicketsAPI.getAll(params);
      
      // If it's the first page, replace all tickets, otherwise append
      if (!params.page || params.page === 1) {
        commit(types.SET_TICKETS, response.data);
      } else {
        commit(types.APPEND_TICKETS, response.data);
      }
      
      // Try to get total count from headers, fallback to response data length
      const totalCount = parseInt(response.headers['X-Total-Count'] || response.headers['x-total-count'] || response.data.length, 10);
      
      commit(types.SET_TICKETS_META, {
        total: totalCount,
        currentPage: parseInt(params.page || 1, 10),
        perPage: parseInt(params.per_page || 25, 10),
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching tickets:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetching: false });
    }
  },

  async fetchAllTickets({ dispatch, getters }) {
    console.log('fetchAllTickets: Starting to fetch all pages');
    
    // Fetch first page with explicit per_page
    const firstPageData = await dispatch('fetchTickets', { page: 1, per_page: 25 });
    console.log('fetchAllTickets: First page fetched, data length:', firstPageData?.length);
    
    const meta = getters.getMeta;
    console.log('fetchAllTickets: Meta after first page:', meta);
    
    const totalPages = Math.ceil(meta.total / meta.perPage);
    console.log('fetchAllTickets: Total pages calculated:', totalPages);
    
    // Fetch remaining pages if they exist
    const promises = [];
    for (let page = 2; page <= totalPages; page++) {
      console.log(`fetchAllTickets: Queueing page ${page}`);
      promises.push(dispatch('fetchTickets', { page, per_page: 25 }));
    }
    
    if (promises.length > 0) {
      console.log(`fetchAllTickets: Fetching ${promises.length} additional pages`);
      const additionalPages = await Promise.all(promises);
      console.log('fetchAllTickets: Additional pages fetched:', additionalPages.map(page => page?.length));
    } else {
      console.log('fetchAllTickets: No additional pages to fetch');
    }
    
    const allTickets = getters.getTickets;
    console.log('fetchAllTickets: Total tickets in store:', allTickets.length);
    
    return allTickets;
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

  // Action for adding tickets from WebSocket events
  addTicket({ commit }, ticketData) {
    console.log('Tickets Store: Adding ticket from WebSocket', ticketData);
    commit(types.ADD_TICKET, ticketData);
    if (ticketData.conversation && ticketData.conversation.id) {
      commit(types.ADD_TICKET_TO_CONVERSATION, {
        conversationId: ticketData.conversation.id,
        ticket: ticketData,
      });
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

  async linkJiraIssue({ commit }, { ticketId, jiraIssueKey, jiraUrl }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.linkJiraIssue(ticketId, jiraIssueKey, jiraUrl);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error linking JIRA issue to ticket:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  // WebSocket action for real-time ticket updates
  updateTicketFromWebSocket({ commit, state }, ticketData) {
    console.log('Tickets Store: Updating ticket from WebSocket', ticketData);
    
    // Check if this ticket exists in our store
    const existingTicket = state.records[ticketData.ticket_id || ticketData.id];
    
    if (existingTicket) {
      // Create updated ticket object, merging WebSocket data with existing ticket
      const updatedTicket = {
        ...existingTicket,
        status: ticketData.status || existingTicket.status,
        priority: ticketData.priority || existingTicket.priority,
        resolved_at: ticketData.resolved_at || existingTicket.resolved_at,
        updated_at: ticketData.updated_at || existingTicket.updated_at,
        jira_issue_key: ticketData.jira_issue_key !== undefined ? ticketData.jira_issue_key : existingTicket.jira_issue_key,
        jira_status: ticketData.jira_status !== undefined ? ticketData.jira_status : existingTicket.jira_status,
        jira_in_progress: ticketData.jira_in_progress !== undefined ? ticketData.jira_in_progress : existingTicket.jira_in_progress,
        escalated_to_jira: ticketData.escalated_to_jira !== undefined ? ticketData.escalated_to_jira : existingTicket.escalated_to_jira,
        // Preserve other fields that might not be in the WebSocket data
      };
      
      commit(types.UPDATE_TICKET, updatedTicket);
      console.log('Tickets Store: Ticket updated via WebSocket', updatedTicket);
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

  [types.APPEND_TICKETS]($state, tickets) {
    tickets.forEach(ticket => {
      $state.records[ticket.id] = ticket;
    });
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
