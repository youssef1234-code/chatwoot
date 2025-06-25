class Api::V1::Accounts::NpsSurveyResponsesController < Api::V1::Accounts::BaseController
  include Sift
  include DateRangeHelper

  RESULTS_PER_PAGE = 25

  before_action :check_authorization
  before_action :set_nps_survey_responses, only: [:index, :metrics, :download]
  before_action :set_current_page, only: [:index]
  before_action :set_current_page_surveys, only: [:index]
  before_action :set_total_sent_messages_count, only: [:metrics]

  sort_on :created_at, type: :datetime

  def index; end

  def metrics
    @total_count = @nps_survey_responses.count
    @ratings_count = @nps_survey_responses.group(:rating).count
    @nps_score = calculate_nps_score
  end

  def download
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = 'attachment; filename=nps_report.csv'
    render layout: false, template: 'api/v1/accounts/nps_survey_responses/download', formats: [:csv]
  end

  private

  def calculate_nps_score
    return 0 if @total_count.zero?

    promoters = @nps_survey_responses.where(rating: 9..10).count
    detractors = @nps_survey_responses.where(rating: 0..6).count
    
    ((promoters - detractors).to_f / @total_count * 100).round(2)
  end

  def set_total_sent_messages_count
    @nps_messages = Current.account.messages.input_nps
    @nps_messages = @nps_messages.where(created_at: range) if range.present?
    @total_sent_messages_count = @nps_messages.count
  end

  def set_nps_survey_responses
    base_query = Current.account.nps_survey_responses.includes([:conversation, :assigned_agent, :contact])
    @nps_survey_responses = filtrate(base_query).filter_by_created_at(range)
                                                .filter_by_assigned_agent_id(params[:user_ids])
                                                .filter_by_inbox_id(params[:inbox_id])
                                                .filter_by_team_id(params[:team_id])
                                                .filter_by_rating(params[:rating])
  end

  def set_current_page_surveys
    @nps_survey_responses = @nps_survey_responses.page(@current_page).per(RESULTS_PER_PAGE)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end
