FactoryBot.define do
  factory :platform do
    name { Faker::Commerce.product_name } # Generates a random name
    description { Faker::Lorem.sentence } # Generates a random description
    price { Faker::Commerce.price(range: 10.0..100.0) } # Generates a random price
    image { Faker::Internet.url(host: 'example.com', path: '/image.png') } # Random image URL
    created_at { Faker::Time.backward(days: 14, period: :evening) }
    updated_at { Faker::Time.backward(days: 7, period: :evening) }
    is_priority { [true, false].sample } # Random true/false
    tax { Faker::Number.decimal(l_digits: 2, r_digits: 2) } # Random tax value
    is_active { [true, false].sample } # Random true/false
    most_popular { [true, false].sample } # Random true/false
    tag_line { Faker::Marketing.buzzwords } # Random marketing tagline
    bg_image { Faker::Internet.url(host: 'example.com', path: '/bg_image.png') } # Random image URL
    primary_color { Faker::Color.hex_color } # Random hex color
    secondary_color { Faker::Color.hex_color } # Random hex color
    features { Faker::Lorem.words(number: 5).join(', ') } # Random list of features
    category_id { nil } # Set to nil or associate with a category in tests
    is_dropdown { [true, false].sample } # Random true/false
    dropdown_options { nil } # Can be set dynamically in tests
    is_slider { [true, false].sample } # Random true/false
    slider_range { (1..10).to_a.sample(2).join('-') } # Random slider range
    parent_id { nil } # Can be associated in tests if necessary

    # Optional: Create child associations if relevant
    after(:create) do |platform, evaluator|
      create_list(:platform, evaluator.children_count, parent: platform) if evaluator.respond_to?(:children_count)
    end

    # Optional: Allow for creating with parent association
    trait :with_parent do
      association :parent, factory: :platform
    end

    # Optional: Allow for creating with children
    transient do
      children_count { 0 } # Default to 0 children
    end
  end
end
