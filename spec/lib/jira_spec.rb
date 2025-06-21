require 'rails_helper'

RSpec.describe Jira do
  describe '.client' do
    let(:access_token) { 'test_token' }
    let(:instance_url) { 'https://test.atlassian.net' }

    it 'creates a Jira client with the given access token and instance URL' do
      client = described_class.client(access_token, instance_url)
      expect(client).to be_a(JIRA::Client)
    end

    it 'uses basic auth with the access token' do
      client = described_class.client(access_token, instance_url)
      expect(client.options[:username]).to eq(access_token)
    end

    it 'sets the correct site URL' do
      client = described_class.client(access_token, instance_url)
      expect(client.options[:site]).to eq(instance_url)
    end
  end

  describe '.search_issues' do
    let(:access_token) { 'test_token' }
    let(:instance_url) { 'https://test.atlassian.net' }
    let(:client) { double('JIRA::Client') }
    let(:issue) { double('JIRA::Resource::Issue', id: 'PROJ1-123', key: 'PROJ1-123') }

    before do
      allow(described_class).to receive(:client).and_return(client)
    end

    context 'when search is successful' do
      it 'returns search results' do
        allow(client).to receive_message_chain(:Issue, :jql).with("summary ~ \"test query\"").and_return([issue])
        
        result = described_class.search_issues(access_token, instance_url, 'test query')
        
        expect(result).to eq([issue])
      end
    end

    context 'when search fails' do
      it 'returns empty array on error' do
        allow(client).to receive_message_chain(:Issue, :jql).and_raise(StandardError.new('API Error'))
        
        result = described_class.search_issues(access_token, instance_url, 'test query')
        
        expect(result).to eq([])
      end
    end
  end

  describe '.get_projects' do
    let(:access_token) { 'test_token' }
    let(:instance_url) { 'https://test.atlassian.net' }
    let(:client) { double('JIRA::Client') }
    let(:project) { double('JIRA::Resource::Project', id: 'PROJ1', key: 'PROJ1', name: 'Project 1') }

    before do
      allow(described_class).to receive(:client).and_return(client)
    end

    context 'when request is successful' do
      it 'returns projects' do
        allow(client).to receive_message_chain(:Project, :all).and_return([project])
        
        result = described_class.get_projects(access_token, instance_url)
        
        expect(result).to eq([project])
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        allow(client).to receive_message_chain(:Project, :all).and_raise(StandardError.new('API Error'))
        
        result = described_class.get_projects(access_token, instance_url)
        
        expect(result).to eq([])
      end
    end
  end

  describe '.create_issue' do
    let(:access_token) { 'test_token' }
    let(:instance_url) { 'https://test.atlassian.net' }
    let(:client) { double('JIRA::Client') }
    let(:issue_class) { double('JIRA::Resource::Issue') }
    let(:created_issue) { double('JIRA::Resource::Issue', id: 'PROJ1-123', key: 'PROJ1-123') }

    let(:issue_params) do
      {
        project_key: 'PROJ1',
        summary: 'Test Issue',
        description: 'Test description',
        issue_type_id: '10001'
      }
    end

    before do
      allow(described_class).to receive(:client).and_return(client)
      allow(client).to receive(:Issue).and_return(issue_class)
    end

    context 'when creation is successful' do
      it 'creates and returns the issue' do
        expected_fields = {
          'project' => { 'key' => 'PROJ1' },
          'summary' => 'Test Issue',
          'description' => 'Test description',
          'issuetype' => { 'id' => '10001' }
        }

        allow(issue_class).to receive(:build).and_return(created_issue)
        allow(created_issue).to receive(:save).and_return(true)
        allow(created_issue).to receive(:fetch)

        result = described_class.create_issue(access_token, instance_url, issue_params)

        expect(issue_class).to have_received(:build).with(expected_fields)
        expect(result).to eq(created_issue)
      end
    end

    context 'when creation fails' do
      it 'returns nil on error' do
        allow(issue_class).to receive(:build).and_raise(StandardError.new('API Error'))

        result = described_class.create_issue(access_token, instance_url, issue_params)

        expect(result).to be_nil
      end
    end
  end

  describe '.add_comment_to_issue' do
    let(:access_token) { 'test_token' }
    let(:instance_url) { 'https://test.atlassian.net' }
    let(:client) { double('JIRA::Client') }
    let(:issue) { double('JIRA::Resource::Issue') }
    let(:comment) { double('JIRA::Resource::Comment', id: 'comment123') }

    before do
      allow(described_class).to receive(:client).and_return(client)
    end

    context 'when comment is added successfully' do
      it 'adds comment and returns it' do
        allow(client).to receive_message_chain(:Issue, :find).with('PROJ1-123').and_return(issue)
        allow(issue).to receive_message_chain(:comments, :build).and_return(comment)
        allow(comment).to receive(:save).and_return(true)

        result = described_class.add_comment_to_issue(access_token, instance_url, 'PROJ1-123', 'Test comment')

        expect(result).to eq(comment)
      end
    end

    context 'when adding comment fails' do
      it 'returns nil on error' do
        allow(client).to receive_message_chain(:Issue, :find).and_raise(StandardError.new('API Error'))

        result = described_class.add_comment_to_issue(access_token, instance_url, 'PROJ1-123', 'Test comment')

        expect(result).to be_nil
      end
    end
  end
end
