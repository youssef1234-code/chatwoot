/* global axios */
import ApiClient from './ApiClient';

class TicketsReportsAPI extends ApiClient {
  constructor() {
    super('reports/tickets', { accountScoped: true });
  }

  get({
    from,
    to,
    status,
    priority,
    category,
    assigned_agent_id,
    linked_with_jira,
    jira_status,
    page,
    businessHours,
    feature_requests_only,
    include_feature_requests,
  } = {}) {
    return axios.get(this.url, {
      params: {
        from,
        to,
        status,
        priority,
        category,
        assigned_agent_id,
        linked_with_jira,
        jira_status,
        page,
        business_hours: businessHours,
        feature_requests_only,
        include_feature_requests,
      },
    });
  }

  getMetrics({
    from,
    to,
    status,
    priority,
    category,
    assigned_agent_id,
    linked_with_jira,
    jira_status,
    businessHours,
    feature_requests_only,
    include_feature_requests,
  } = {}) {
    return axios.get(`${this.url}/metrics`, {
      params: {
        from,
        to,
        status,
        priority,
        category,
        assigned_agent_id,
        linked_with_jira,
        jira_status,
        business_hours: businessHours,
        feature_requests_only,
        include_feature_requests,
      },
    });
  }

  getSummary({
    from,
    to,
    status,
    priority,
    category,
    assigned_agent_id,
    linked_with_jira,
    jira_status,
    businessHours,
    feature_requests_only,
    include_feature_requests,
  } = {}) {
    return axios.get(`${this.url}/summary`, {
      params: {
        from,
        to,
        status,
        priority,
        category,
        assigned_agent_id,
        linked_with_jira,
        jira_status,
        business_hours: businessHours,
        feature_requests_only,
        include_feature_requests,
      },
    });
  }
  download({
    from,
    to,
    status,
    priority,
    category,
    assigned_agent_id,
    linked_with_jira,
    jira_status,
    businessHours,
    fileName,
    feature_requests_only,
    include_feature_requests,
  } = {}) {
    return axios.get(`${this.url}/download`, {
      params: {
        from,
        to,
        status,
        priority,
        category,
        assigned_agent_id,
        linked_with_jira,
        jira_status,
        business_hours: businessHours,
        feature_requests_only,
        include_feature_requests,
      },
      responseType: 'blob',
    });
  }
}

export default new TicketsReportsAPI();
