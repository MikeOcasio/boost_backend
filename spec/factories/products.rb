# spec/factories/products.rb
FactoryBot.define do
  factory :product do
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.paragraph }
    price { Faker::Commerce.price(range: 10.0..100.0) }
    image { Faker::Internet.url(scheme: 'https') } # Generate a random URL
    association :category # Links to the `Category` factory
    association :product_attribute_category # Links to `ProductAttributeCategory` factory

    # Optional trait for creating a priority product
    trait :priority do
      is_priority { true }
    end
  end
end
