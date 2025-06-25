require 'rails_helper'

describe NpsSurveyService do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account, csat_survey_enabled: true) }
  let!(:contact) { create(:contact, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: user, status: :resolved) }

  describe '#perform' do
    context 'when NPS survey conditions are met' do
      it 'sends NPS survey when no previous NPS exists for contact' do
        service = described_class.new(conversation: conversation)
        expect(service).to receive(:within_messaging_window?).and_return(true)
        
        expect {
          service.perform
        }.to change { conversation.messages.where(content_type: 'input_nps').count }.by(1)
      end

      it 'does not send NPS survey when one was sent in the last month' do
        # Create an existing NPS response from 2 weeks ago
        create(:nps_survey_response, 
               contact: contact, 
               account: account,
               created_at: 2.weeks.ago)

        service = described_class.new(conversation: conversation)
        expect(service).not_to receive(:within_messaging_window?)
        
        expect {
          service.perform
        }.not_to change { conversation.messages.where(content_type: 'input_nps').count }
      end

      it 'sends NPS survey when previous one was sent over a month ago' do
        # Create an existing NPS response from 2 months ago
        create(:nps_survey_response, 
               contact: contact, 
               account: account,
               created_at: 2.months.ago)

        service = described_class.new(conversation: conversation)
        expect(service).to receive(:within_messaging_window?).and_return(true)
        
        expect {
          service.perform
        }.to change { conversation.messages.where(content_type: 'input_nps').count }.by(1)
      end
    end

    context 'when NPS survey conditions are not met' do
      it 'does not send NPS survey when conversation is not resolved' do
        conversation.update!(status: :open)
        service = described_class.new(conversation: conversation)
        
        expect {
          service.perform
        }.not_to change { conversation.messages.where(content_type: 'input_nps').count }
      end

      it 'does not send NPS survey when CSAT is not enabled' do
        inbox.update!(csat_survey_enabled: false)
        service = described_class.new(conversation: conversation)
        
        expect {
          service.perform
        }.not_to change { conversation.messages.where(content_type: 'input_nps').count }
      end
    end
  end
end
