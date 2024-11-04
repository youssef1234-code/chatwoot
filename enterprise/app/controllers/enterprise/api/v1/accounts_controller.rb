class Enterprise::Api::V1::AccountsController < Api::BaseController
  before_action :fetch_account
  before_action :check_authorization

  def show
    # Define any basic account details that should be returned
    render json: { id: @account.id, name: @account.name }, status: :ok
  end

  private

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
