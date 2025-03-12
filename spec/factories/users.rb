require 'rotp'

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'Password123!' } # Ensure password meets complexity requirements
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    password { 'Password123!' }
    password_confirmation { 'Password123!' }
    role { 'customer' }
    otp_secret { nil } # You can modify this as needed, especially if you're testing 2FA
    otp_required_for_login { false } # Adjust based on your tests
    platform_credentials { [] } # Assuming platform credentials are optional for the factory
    gamer_tag { Faker::Internet.username }
    bio { Faker::Lorem.paragraph }
    image_url { Faker::Internet.url(host: 'example.com', path: '/avatar.jpg') }
    achievements { [] }
    gameplay_info { {} }
    preferred_skill_master_ids { [] }
    platforms { [] }

    # Remove the automatic creation of platforms and categories
    # Only create them when specifically needed using traits
    # Default values
    otp_required_for_login { false }
    otp_setup_complete { false }
    two_factor_method { 'none' }
    locked_by_admin { false }
    deleted_at { nil }

    # Devise/Authentication related
    confirmed_at { Time.current }
    confirmation_sent_at { 1.day.ago }
    sign_in_count { 0 }
    current_sign_in_at { nil }
    last_sign_in_at { nil }
    current_sign_in_ip { nil }
    last_sign_in_ip { nil }

    trait :with_platforms do
      after(:create) do |user|
        create_list(:platform, 2, users: [user])
      end
    end

    trait :with_2fa do
      otp_required_for_login { true }
      otp_setup_complete { true }
      otp_secret { ROTP::Base32.random }
      two_factor_method { 'app' }
    end

    trait :locked do
      locked_at { Time.current }
      failed_attempts { 3 }
    end

    trait :admin_locked do
      locked_by_admin { true }
    end

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :with_gameplay_info do
      gameplay_info do
        {
          'preferred_games' => ['Game1', 'Game2'],
          'skill_level' => 'intermediate'
        }
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

    factory :admin_user, traits: [:admin]
    factory :skillmaster_user, traits: [:skillmaster]
    factory :locked_user, traits: [:locked]
    trait :with_achievements do
      achievements do
        [
          { 'title' => 'First Order', 'earned_at' => Time.current.iso8601 },
          { 'title' => 'Top Rated', 'earned_at' => Time.current.iso8601 }
        ]
      end
    end

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

    factory :admin do
      role { 'admin' }
    end

    factory :dev do
      role { 'dev' }
    end
  end
end
