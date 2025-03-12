# spec/factories/categories.rb
FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    description { 'Test category description' }
    is_active { true }
    image { nil }
    bg_image { nil }

    trait :with_image do
      image { 'https://example-bucket.s3.amazonaws.com/categories/test.jpg' }
    end

    trait :with_bg_image do
      bg_image { 'https://example-bucket.s3.amazonaws.com/categories/test-bg.jpg' }
    end

    trait :with_products do
      after(:create) do |category|
        create_list(:product, 3, category: category)
      end
    end
  end
end
