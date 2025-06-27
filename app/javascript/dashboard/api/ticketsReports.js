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
    jira_status,
    businessHours,
    fileName,
  } = {}) {
    return axios.get(`${this.url}/download`, {
      params: {
        from,
        to,
        status,
        priority,
        category,
        assigned_agent_id,
        jira_status,
        business_hours: businessHours,
      },
      responseType: 'blob',
    });
  }
}

export default new TicketsReportsAPI();
