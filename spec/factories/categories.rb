# spec/factories/categories.rb
FactoryBot.define do
  factory :category do
    name { Faker::Commerce.department } # Using Faker for generating random category names
    description { Faker::Lorem.sentence }

    # Optional trait for creating a category with products
    trait :with_products do
      after(:create) do |category|
        create_list(:product, 3, category: category)
      end
    end
  end
end
