FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'Password123!' }  # Ensure password meets complexity requirements
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { 'customer' }
    otp_secret { nil }  # You can modify this as needed, especially if you're testing 2FA
    otp_required_for_login { false }  # Adjust based on your tests
    platform_credentials { [] }  # Assuming platform credentials are optional for the factory

    # Optional associations
    # Creates a user with platforms, preferred skill masters, and categories
    after(:create) do |user|
      create_list(:platform, 2, users: [user]) # Create 2 associated platforms
      create_list(:category, 2, users: [user])  # Create 2 associated categories
    end

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

    factory :admin_user, traits: [:admin]
    factory :skillmaster_user, traits: [:skillmaster]
    factory :locked_user, traits: [:locked]
  end
end
