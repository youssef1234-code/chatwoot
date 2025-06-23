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

  async getForConversation(conversationId) {
    return axios.get(this.url, {
      params: { conversation_id: conversationId },
    });
  }
}

export default new TicketsAPI();
