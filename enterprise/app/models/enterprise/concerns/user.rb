module Enterprise::Concerns::User
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_user_constraints, on: :create
  end

  def ensure_user_constraints
    # Any essential validations for user creation can be placed here
  end
end
