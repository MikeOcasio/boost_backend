FactoryBot.define do
  factory :chat_participant do
    association :chat
    association :user

    trait :skillmaster do
      association :user, factory: :skillmaster
    end

    trait :customer do
      association :user, factory: :customer
    end

    trait :admin do
      association :user, factory: :admin
    end
  end
end
