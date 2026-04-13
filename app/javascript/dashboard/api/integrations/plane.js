/* global axios */
import ApiClient from '../ApiClient';

class PlaneAPI extends ApiClient {
  constructor() {
    super('integrations/plane', { accountScoped: true });
  }

  testConnection() {
    return axios.get(`${this.url}/test_connection`);
  }

  getProjects() {
    return axios.get(`${this.url}/projects`);
  }

  getProjectMetadata(projectId) {
    return axios.get(`${this.url}/project_metadata?project_id=${projectId}`);
  }

  createIssue(data) {
    return axios.post(`${this.url}/create_issue`, data);
  }

  linkIssue(conversationId, projectId, issueId, title) {
    return axios.post(`${this.url}/link_issue`, {
      project_id: projectId,
      issue_id: issueId,
      conversation_id: conversationId,
      title: title,
    });
  }

  getLinkedIssues(conversationId) {
    return axios.get(
      `${this.url}/linked_issues?conversation_id=${conversationId}`
    );
  }

  unlinkIssue(projectId, issueId, conversationId) {
    return axios.post(`${this.url}/unlink_issue`, {
      project_id: projectId,
      issue_id: issueId,
      conversation_id: conversationId,
    });
  }

  getWebhookSecretStatus() {
    return axios.get(`${this.url}/webhook_secret_status`);
  }

  updateWebhookSecret(secret) {
    return axios.post(`${this.url}/update_webhook_secret`, {
      webhook_secret: secret,
    });
  }

  searchIssues(query, projectId = null) {
    let url = `${this.url}/search_issues?q=${encodeURIComponent(query)}`;
    if (projectId) {
      url += `&project_id=${projectId}`;
    }
    return axios.get(url);
  }

  getIssue(projectId, issueId) {
    return axios.get(`${this.url}/get_issue?project_id=${projectId}&issue_id=${issueId}`);
  }

  getComments(projectId, issueId) {
    return axios.get(`${this.url}/get_comments?project_id=${projectId}&issue_id=${issueId}`);
  }

  addComment(projectId, issueId, commentBody) {
    return axios.post(`${this.url}/add_comment`, {
      project_id: projectId,
      issue_id: issueId,
      comment_body: commentBody,
    });
  }

  addAttachment(projectId, issueId, file) {
    const formData = new FormData();
    formData.append('project_id', projectId);
    formData.append('issue_id', issueId);
    formData.append('file', file);
    
    return axios.post(`${this.url}/add_attachment`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  updateIssue(projectId, issueId, data) {
    return axios.post(`${this.url}/update_issue`, {
      project_id: projectId,
      issue_id: issueId,
      ...data,
    });
  }

  getPlaneStatuses(projectId = null) {
    let url = `${this.url}/plane_statuses`;
    if (projectId) {
      url += `?project_id=${projectId}`;
    }
    return axios.get(url);
  }

  getPlaneSettings() {
    return axios.get(`${this.url}/plane_settings`);
  }

  updatePlaneSettings(settings) {
    return axios.post(`${this.url}/update_plane_settings`, settings);
  }
}

export default new PlaneAPI();
