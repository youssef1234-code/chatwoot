import TicketsAPI from '../../api/tickets';
import types from '../mutation-types';

export const state = {
  records: {},
  conversationTickets: {}, // tickets grouped by conversation_id
  conversationTicketsMeta: {}, // pagination meta for conversation tickets
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isFetchingConversationTickets: false,
  },
  meta: {
    total: 0,
    currentPage: 1,
    perPage: 25,
  },
};

export const getters = {
  getTickets: $state => Object.values($state.records).sort((a, b) => b.id - a.id),
  getTicket: $state => ticketId => $state.records[ticketId],
  getTicketsForConversation: $state => conversationId => 
    $state.conversationTickets[conversationId] || [],
  getConversationTicketsMeta: $state => conversationId =>
    $state.conversationTicketsMeta[conversationId] || { total: 0, currentPage: 1, perPage: 10, hasMore: false },
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

  async fetchAllTickets({ dispatch, getters }, params = {}) {
    console.log('fetchAllTickets: Starting to fetch all pages');
    
    // Fetch first page with explicit per_page
    const firstPageData = await dispatch('fetchTickets', { page: 1, per_page: 25, ...params });
    console.log('fetchAllTickets: First page fetched, data length:', firstPageData?.length);
    
    const meta = getters.getMeta;
    console.log('fetchAllTickets: Meta after first page:', meta);
    
    const totalPages = Math.ceil(meta.total / meta.perPage);
    console.log('fetchAllTickets: Total pages calculated:', totalPages);
    
    // Fetch remaining pages if they exist
    const promises = [];
    for (let page = 2; page <= totalPages; page++) {
      console.log(`fetchAllTickets: Queueing page ${page}`);
      promises.push(dispatch('fetchTickets', { page, per_page: 25, ...params }));
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

  async fetchTicketsForConversation({ commit }, { conversationId, page = 1, per_page = 10, append = false, include_feature_requests = false }) {
    commit(types.SET_TICKETS_UI_FLAG, { isFetchingConversationTickets: true });
    try {
      const response = await TicketsAPI.getForConversation(conversationId, { page, per_page, include_feature_requests });
      
      const totalCount = parseInt(response.headers['X-Total-Count'] || response.headers['x-total-count'] || response.data.length, 10);
      const currentPage = parseInt(response.headers['X-Current-Page'] || response.headers['x-current-page'] || page, 10);
      const totalPages = parseInt(response.headers['X-Total-Pages'] || response.headers['x-total-pages'] || 1, 10);
      
      commit(types.SET_CONVERSATION_TICKETS, { 
        conversationId, 
        tickets: response.data,
        append,
      });
      
      commit(types.SET_CONVERSATION_TICKETS_META, {
        conversationId,
        meta: {
          total: totalCount,
          currentPage,
          perPage: per_page,
          hasMore: currentPage < totalPages,
        },
      });
      
      return response.data;
    } catch (error) {
      console.error('Error fetching tickets for conversation:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isFetchingConversationTickets: false });
    }
  },

  async loadMoreTicketsForConversation({ commit, getters }, conversationId) {
    const meta = getters.getConversationTicketsMeta(conversationId);
    if (!meta.hasMore) return [];
    
    const nextPage = meta.currentPage + 1;
    return this.dispatch('tickets/fetchTicketsForConversation', {
      conversationId,
      page: nextPage,
      per_page: meta.perPage,
      append: true,
      include_feature_requests: true,
    });
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

  // Convenience method for deleting tickets 
  async deleteTicket({ commit }, ticketId) {
    commit(types.SET_TICKETS_UI_FLAG, { isDeleting: true });
    try {
      await TicketsAPI.delete(ticketId);
      commit(types.DELETE_TICKET, ticketId);
      
      // Note: WebSocket event will be broadcasted from the server
      // which will trigger removeTicketFromWebSocket for other clients
      
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

  async escalateToPlane({ commit }, { ticketId, planeIssueId, planeIssueKey, planeProjectId }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.escalateToPlane(ticketId, { planeIssueId, planeIssueKey, planeProjectId });
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error escalating ticket to Plane:', error);
      throw error;
    } finally {
      commit(types.SET_TICKETS_UI_FLAG, { isUpdating: false });
    }
  },

  async escalate({ commit }, { id, note }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.escalate(id, note);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error escalating ticket:', error);
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

  async linkPlaneIssue({ commit }, { ticketId, planeIssueId, planeIssueKey, planeProjectId }) {
    commit(types.SET_TICKETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await TicketsAPI.linkPlaneIssue(ticketId, planeIssueId, planeIssueKey, planeProjectId);
      commit(types.UPDATE_TICKET, response.data);
      return response.data;
    } catch (error) {
      console.error('Error linking Plane issue to ticket:', error);
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
        plane_issue_id: ticketData.plane_issue_id !== undefined ? ticketData.plane_issue_id : existingTicket.plane_issue_id,
        plane_issue_key: ticketData.plane_issue_key !== undefined ? ticketData.plane_issue_key : existingTicket.plane_issue_key,
        plane_project_id: ticketData.plane_project_id !== undefined ? ticketData.plane_project_id : existingTicket.plane_project_id,
        plane_status: ticketData.plane_status !== undefined ? ticketData.plane_status : existingTicket.plane_status,
        plane_in_progress: ticketData.plane_in_progress !== undefined ? ticketData.plane_in_progress : existingTicket.plane_in_progress,
        escalated_to_plane: ticketData.escalated_to_plane !== undefined ? ticketData.escalated_to_plane : existingTicket.escalated_to_plane,
      };
      
      commit(types.UPDATE_TICKET, updatedTicket);
      console.log('Tickets Store: Ticket updated via WebSocket', updatedTicket);
    } else {
      console.log('Tickets Store: Ticket not found in store, ignoring WebSocket update');
    }
  },

  // WebSocket action to remove ticket when deleted by another user/tab
  removeTicketFromWebSocket({ commit }, ticketId) {
    console.log('Tickets store: Removing ticket from WebSocket', ticketId);
    commit(types.DELETE_TICKET, ticketId);
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

  [types.SET_CONVERSATION_TICKETS]($state, { conversationId, tickets, append = false }) {
    if (append && $state.conversationTickets[conversationId]) {
      // Append new tickets, avoiding duplicates
      const existingIds = new Set($state.conversationTickets[conversationId].map(t => t.id));
      const newTickets = tickets.filter(ticket => !existingIds.has(ticket.id));
      $state.conversationTickets[conversationId].push(...newTickets);
    } else {
      // Replace all tickets
      $state.conversationTickets[conversationId] = [...tickets];
    }
    
    // Sort tickets by ID in descending order (newest first)
    $state.conversationTickets[conversationId].sort((a, b) => b.id - a.id);
    
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
    
    // Sort tickets by ID in descending order (newest first)
    $state.conversationTickets[conversationId].sort((a, b) => b.id - a.id);
  },

  [types.SET_TICKETS_META]($state, meta) {
    Object.assign($state.meta, meta);
  },

  [types.SET_CONVERSATION_TICKETS_META]($state, { conversationId, meta }) {
    $state.conversationTicketsMeta[conversationId] = meta;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
