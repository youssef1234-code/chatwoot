FactoryBot.define do
  factory :nps_survey_response do
    account
    contact
    conversation
    message
    rating { rand(0..10) }
    feedback_message { Faker::Lorem.sentence }
    assigned_agent { create(:user, account: account) }

    trait :promoter do
      rating { rand(9..10) }
    end

    trait :passive do
      rating { rand(7..8) }
    end

    trait :detractor do
      rating { rand(0..6) }
    end
  end
end
