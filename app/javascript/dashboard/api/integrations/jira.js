import ApiClient from '../ApiClient';

class JiraAPI extends ApiClient {
  constructor() {
    super('integrations/jira', { accountScoped: true });
  }

  getProjects() {
    return axios.get(`${this.url}/projects`);
  }

  getProjectMetadata(projectKey) {
    return axios.get(`${this.url}/project_metadata?project_key=${projectKey}`);
  }

  createIssue(data) {
    return axios.post(`${this.url}/create_issue`, data);
  }

  linkIssue(conversationId, issueKey, title) {
    return axios.post(`${this.url}/link_issue`, {
      issue_key: issueKey,
      conversation_id: conversationId,
      title: title,
    });
  }

  getLinkedIssues(conversationId) {
    return axios.get(
      `${this.url}/linked_issues?conversation_id=${conversationId}`
    );
  }

  unlinkIssue(issueKey, commentId, conversationId) {
    return axios.post(`${this.url}/unlink_issue`, {
      issue_key: issueKey,
      comment_id: commentId,
      conversation_id: conversationId,
    });
  }

  searchIssues(query) {
    return axios.get(`${this.url}/search_issue?q=${query}`);
  }

  getIssue(issueKey) {
    return axios.get(`${this.url}/get_issue?issue_key=${issueKey}`);
  }

  getComments(issueKey) {
    return axios.get(`${this.url}/get_comments?issue_key=${issueKey}`);
  }

  addComment(issueKey, commentBody) {
    return axios.post(`${this.url}/add_comment`, {
      issue_key: issueKey,
      comment_body: commentBody,
    });
  }

  addAttachment(issueKey, file) {
    const formData = new FormData();
    formData.append('issue_key', issueKey);
    formData.append('file', file);
    
    return axios.post(`${this.url}/add_attachment`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  uploadAttachment(issueKey, formData) {
    formData.append('issue_key', issueKey);
    
    return axios.post(`${this.url}/add_attachment`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }
}

export default new JiraAPI();
