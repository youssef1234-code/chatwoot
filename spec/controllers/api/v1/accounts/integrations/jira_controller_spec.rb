require 'rails_helper'

RSpec.describe 'JIRA Integration API', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:api_key) { 'valid_api_key' }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:processor_service) { instance_double(Integrations::Jira::ProcessorService) }

  before do
    create(:integrations_hook, :jira, account: account)
    allow(Integrations::Jira::ProcessorService).to receive(:new).with(account: account).and_return(processor_service)
  end

  describe 'DELETE /api/v1/accounts/:account_id/integrations/jira' do
    it 'deletes the JIRA integration' do
      delete "/api/v1/accounts/#{account.id}/integrations/jira",
             headers: agent.create_new_auth_token,
             as: :json
      expect(response).to have_http_status(:ok)
      expect(account.hooks.count).to eq(0)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/jira/projects' do
    context 'when it is an authenticated user' do
      context 'when data is retrieved successfully' do
        let(:projects_data) { { data: [{ 'id' => 'proj1', 'name' => 'Project One', 'key' => 'PROJ1' }] } }

        it 'returns project data' do
          allow(processor_service).to receive(:projects).and_return(projects_data)
          get "/api/v1/accounts/#{account.id}/integrations/jira/projects",
              headers: agent.create_new_auth_token,
              as: :json
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('Project One')
        end
      end

      context 'when data retrieval fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:projects).and_return(error: 'error message')
          get "/api/v1/accounts/#{account.id}/integrations/jira/projects",
              headers: agent.create_new_auth_token,
              as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('error message')
        end
      end
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/integrations/jira/projects", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/jira/project_entities' do
    context 'when it is an authenticated user' do
      context 'when data is retrieved successfully' do
        let(:entities_data) do
          {
            data: {
              issue_types: [{ 'id' => 'type1', 'name' => 'Bug' }],
              priorities: [{ 'id' => 'high', 'name' => 'High' }],
              users: [{ 'accountId' => 'user1', 'displayName' => 'John Doe' }]
            }
          }
        end

        it 'returns project entities data' do
          allow(processor_service).to receive(:project_entities).with('PROJ1').and_return(entities_data)
          get "/api/v1/accounts/#{account.id}/integrations/jira/project_entities",
              headers: agent.create_new_auth_token,
              params: { project_key: 'PROJ1' },
              as: :json
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('Bug')
          expect(response.body).to include('John Doe')
        end
      end

      context 'when data retrieval fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:project_entities).and_return(error: 'error message')
          get "/api/v1/accounts/#{account.id}/integrations/jira/project_entities",
              headers: agent.create_new_auth_token,
              params: { project_key: 'PROJ1' },
              as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('error message')
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/jira/create_issue' do
    context 'when it is an authenticated user' do
      let(:conversation) { create(:conversation, account: account) }
      let(:create_params) do
        {
          conversation_id: conversation.id,
          title: 'Test Issue',
          description: 'Test description',
          project_key: 'PROJ1',
          issue_type_id: 'bug'
        }
      end

      context 'when issue is created successfully' do
        let(:issue_data) { { data: { 'id' => 'PROJ1-123', 'key' => 'PROJ1-123', 'fields' => { 'summary' => 'Test Issue' } } } }

        it 'creates and returns issue data' do
          allow(processor_service).to receive(:create_issue).with(create_params).and_return(issue_data)
          post "/api/v1/accounts/#{account.id}/integrations/jira/create_issue",
               headers: agent.create_new_auth_token,
               params: create_params,
               as: :json
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('PROJ1-123')
        end
      end

      context 'when issue creation fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:create_issue).and_return(error: 'creation failed')
          post "/api/v1/accounts/#{account.id}/integrations/jira/create_issue",
               headers: agent.create_new_auth_token,
               params: create_params,
               as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('creation failed')
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/jira/link_issue' do
    context 'when it is an authenticated user' do
      let(:conversation) { create(:conversation, account: account) }
      let(:link_params) do
        {
          conversation_id: conversation.id,
          issue_id: 'PROJ1-123',
          title: 'Link conversation'
        }
      end

      context 'when issue is linked successfully' do
        let(:link_data) { { data: { 'id' => 'comment123' } } }

        it 'links issue and returns success' do
          allow(processor_service).to receive(:link_issue).with(link_params).and_return(link_data)
          post "/api/v1/accounts/#{account.id}/integrations/jira/link_issue",
               headers: agent.create_new_auth_token,
               params: link_params,
               as: :json
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when issue linking fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:link_issue).and_return(error: 'linking failed')
          post "/api/v1/accounts/#{account.id}/integrations/jira/link_issue",
               headers: agent.create_new_auth_token,
               params: link_params,
               as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('linking failed')
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/jira/unlink_issue' do
    context 'when it is an authenticated user' do
      let(:conversation) { create(:conversation, account: account) }
      let(:unlink_params) do
        {
          conversation_id: conversation.id,
          issue_id: 'PROJ1-123',
          comment_id: 'comment123'
        }
      end

      context 'when issue is unlinked successfully' do
        it 'unlinks issue and returns success' do
          allow(processor_service).to receive(:unlink_issue).with(unlink_params).and_return({ data: {} })
          post "/api/v1/accounts/#{account.id}/integrations/jira/unlink_issue",
               headers: agent.create_new_auth_token,
               params: unlink_params,
               as: :json
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when issue unlinking fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:unlink_issue).and_return(error: 'unlinking failed')
          post "/api/v1/accounts/#{account.id}/integrations/jira/unlink_issue",
               headers: agent.create_new_auth_token,
               params: unlink_params,
               as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('unlinking failed')
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/jira/search_issue' do
    context 'when it is an authenticated user' do
      context 'when search is successful' do
        let(:search_results) { { data: [{ 'id' => 'PROJ1-123', 'key' => 'PROJ1-123', 'fields' => { 'summary' => 'Test Issue' } }] } }

        it 'returns search results' do
          allow(processor_service).to receive(:search_issue).with('test').and_return(search_results)
          get "/api/v1/accounts/#{account.id}/integrations/jira/search_issue",
              headers: agent.create_new_auth_token,
              params: { q: 'test' },
              as: :json
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('PROJ1-123')
        end
      end

      context 'when search fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:search_issue).and_return(error: 'search failed')
          get "/api/v1/accounts/#{account.id}/integrations/jira/search_issue",
              headers: agent.create_new_auth_token,
              params: { q: 'test' },
              as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('search failed')
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/jira/linked_issues' do
    context 'when it is an authenticated user' do
      let(:conversation) { create(:conversation, account: account) }

      context 'when linked issues are retrieved successfully' do
        let(:linked_issues) { { data: [{ 'id' => 'PROJ1-123', 'key' => 'PROJ1-123', 'comment_id' => 'comment123' }] } }

        it 'returns linked issues' do
          allow(processor_service).to receive(:linked_issues).with(conversation.id).and_return(linked_issues)
          get "/api/v1/accounts/#{account.id}/integrations/jira/linked_issues",
              headers: agent.create_new_auth_token,
              params: { conversation_id: conversation.id },
              as: :json
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('PROJ1-123')
        end
      end

      context 'when retrieval fails' do
        it 'returns error message' do
          allow(processor_service).to receive(:linked_issues).and_return(error: 'retrieval failed')
          get "/api/v1/accounts/#{account.id}/integrations/jira/linked_issues",
              headers: agent.create_new_auth_token,
              params: { conversation_id: conversation.id },
              as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('retrieval failed')
        end
      end
    end
  end
end
