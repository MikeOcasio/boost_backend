FactoryBot.define do
  factory :platform_credential do
    association :user
    association :platform
    username { Faker::Internet.username }
    password { Faker::Internet.password }
    sub_platform_id { nil }
  end
end
