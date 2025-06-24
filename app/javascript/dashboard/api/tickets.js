/* global axios */
import ApiClient from './ApiClient';

class TicketsAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
  }

  async getAll(params = {}) {
    return axios.get(this.url, { params });
  }

  async get(ticketId) {
    return axios.get(`${this.url}/${ticketId}`);
  }

  async create(ticketData) {
    return axios.post(this.url, { ticket: ticketData, message_ids: ticketData.message_ids });
  }

  async update(ticketId, ticketData) {
    return axios.patch(`${this.url}/${ticketId}`, { ticket: ticketData });
  }

  async delete(ticketId) {
    return axios.delete(`${this.url}/${ticketId}`);
  }

  async escalateToJira(ticketId, jiraIssueKey) {
    return axios.post(`${this.url}/${ticketId}/escalate_to_jira`, {
      jira_issue_key: jiraIssueKey,
    });
  }

  async escalate(ticketId, note = null) {
    return axios.post(`${this.url}/${ticketId}/escalate`, {
      note: note,
    });
  }

  async resolve(ticketId) {
    return axios.post(`${this.url}/${ticketId}/resolve`);
  }

  async close(ticketId) {
    return axios.post(`${this.url}/${ticketId}/close`);
  }

  async addMessages(ticketId, messageData) {
    return axios.post(`${this.url}/${ticketId}/add_messages`, messageData);
  }

  async removeMessages(ticketId, messageData) {
    return axios.post(`${this.url}/${ticketId}/remove_messages`, messageData);
  }

  async getMessages(ticketId) {
    return axios.get(`${this.url}/${ticketId}/messages`);
  }

  async getForConversation(conversationId) {
    return axios.get(this.url, {
      params: { conversation_id: conversationId },
    });
  }

  // Additional methods for comprehensive ticket management
  async getByStatus(status) {
    return axios.get(this.url, {
      params: { status },
    });
  }

  async getByPriority(priority) {
    return axios.get(this.url, {
      params: { priority },
    });
  }

  async getByAgent(agentId) {
    return axios.get(this.url, {
      params: { assigned_agent_id: agentId },
    });
  }

  async getCreatedBy(userId) {
    return axios.get(this.url, {
      params: { created_by_id: userId },
    });
  }

  async search(query) {
    return axios.get(this.url, {
      params: { search: query },
    });
  }

  // Analytics and reporting
  async getAnalytics(params = {}) {
    return axios.get(`${this.url}/analytics`, { params });
  }

  async getStats() {
    return axios.get(`${this.url}/stats`);
  }

  async linkJiraIssue(ticketId, jiraIssueKey, jiraUrl) {
    return axios.post(`${this.url}/${ticketId}/link_jira_issue`, {
      jira_issue_key: jiraIssueKey,
      jira_url: jiraUrl,
    });
  }

  async enhanceWithAI(ticketId, enhancementOptions) {
    return axios.post(`${this.url}/${ticketId}/enhance_with_ai`, {
      enhancement_options: enhancementOptions,
    });
  }
}

export default new TicketsAPI();
