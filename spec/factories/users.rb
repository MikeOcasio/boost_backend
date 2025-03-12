require 'rotp'

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'Password123!' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { 'customer' }
    otp_secret { nil }
    otp_required_for_login { false }
    platform_credentials { [] }
    gamer_tag { Faker::Internet.username }
    bio { Faker::Lorem.paragraph }
    image_url { Faker::Internet.url(host: 'example.com', path: '/avatar.jpg') }
    achievements { [] }
    gameplay_info { {} }
    preferred_skill_master_ids { [] }
    platforms { [] }

    trait :admin do
      role { 'admin' }
    end

    trait :skillmaster do
      role { 'skillmaster' }
    end

    trait :customer do
      role { 'customer' }
    end

    trait :locked do
      locked_at { Time.current }
      locked_by_admin { true }
    end

    trait :with_platform_credentials do
      after(:create) do |user|
        create_list(:platform_credential, 2, user: user)
      end
    end

    trait :with_platforms do
      after(:create) do |user|
        create_list(:platform, 2, users: [user])
      end
    end

    trait :with_categories do
      after(:create) do |user|
        create_list(:category, 2, users: [user])
      end
    end

    trait :with_2fa do
      otp_required_for_login { true }
      otp_setup_complete { true }
      otp_secret { ROTP::Base32.random }
      two_factor_method { 'app' }
    end

    trait :with_gameplay_info do
      gameplay_info do
        {
          'preferred_games' => ['Game1', 'Game2'],
          'skill_level' => 'intermediate'
        }
      end
    end

    trait :with_achievements do
      achievements do
        [
          { 'title' => 'First Order', 'earned_at' => Time.current.iso8601 },
          { 'title' => 'Top Rated', 'earned_at' => Time.current.iso8601 }
        ]
      end
    end

    factory :admin_user, traits: [:admin]
    factory :skillmaster_user, traits: [:skillmaster]
    factory :locked_user, traits: [:locked]
    factory :customer do
      role { 'customer' }
    end

    factory :skillmaster do
      role { 'skillmaster' }
      bio { Faker::Lorem.paragraph(sentence_count: 3) }
      gameplay_info do
        {
          'specialties' => ['Game1', 'Game2'],
          'experience_years' => rand(1..10)
        }
      end
    end

    factory :dev do
      role { 'dev' }
    end
  end
end
