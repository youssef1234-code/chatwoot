import JiraAPIClient from '../../integrations/jira';
import ApiClient from '../../ApiClient';

describe('#jiraAPI', () => {
  it('creates correct instance', () => {
    expect(JiraAPIClient).toBeInstanceOf(ApiClient);
    expect(JiraAPIClient).toHaveProperty('getProjects');
    expect(JiraAPIClient).toHaveProperty('getProjectMetadata');
    expect(JiraAPIClient).toHaveProperty('createIssue');
    expect(JiraAPIClient).toHaveProperty('linkIssue');
    expect(JiraAPIClient).toHaveProperty('getLinkedIssues');
    expect(JiraAPIClient).toHaveProperty('unlinkIssue');
    expect(JiraAPIClient).toHaveProperty('searchIssues');
  });

  describe('getProjects', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      JiraAPIClient.getProjects();
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/projects'
      );
    });
  });

  describe('getProjectMetadata', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      JiraAPIClient.getProjectMetadata('PROJ1');
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/project_entities?project_key=PROJ1'
      );
    });
  });

  describe('createIssue', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      const issueData = {
        summary: 'Test Issue',
        description: 'Test description',
        project_key: 'PROJ1',
        issue_type_id: 'bug',
        conversation_id: 123
      };
      JiraAPIClient.createIssue(issueData);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/create_issue',
        issueData
      );
    });
  });

  describe('linkIssue', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      JiraAPIClient.linkIssue(123, 'PROJ1-456', 'Test Link');
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/link_issue',
        {
          conversation_id: 123,
          issue_id: 'PROJ1-456',
          title: 'Test Link'
        }
      );
    });
  });

  describe('unlinkIssue', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      JiraAPIClient.unlinkIssue('PROJ1-456', 'comment123', 123);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/unlink_issue',
        {
          issue_id: 'PROJ1-456',
          comment_id: 'comment123',
          conversation_id: 123
        }
      );
    });
  });

  describe('searchIssues', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      JiraAPIClient.searchIssues('test query');
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/search_issue?q=test%20query'
      );
    });
  });

  describe('getLinkedIssues', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('creates a valid request', () => {
      JiraAPIClient.getLinkedIssues(123);
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/integrations/jira/linked_issues?conversation_id=123'
      );
    });
  });
});
