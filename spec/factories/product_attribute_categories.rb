# spec/factories/product_attribute_categories.rb
# spec/factories/product_attribute_categories.rb
FactoryBot.define do
  factory :product_attribute_category do
    name { Faker::Commerce.material } # Default random category name

    # Trait for predefined categories
    trait :kills do
      name { 'Kills' }
    end

    trait :wins do
      name { 'Wins' }
    end

    trait :badges do
      name { 'Badges' }
    end

    trait :account_leveling do
      name { 'Account Leveling' }
    end

    trait :weapon_leveling do
      name { 'Weapon Leveling' }
    end

    trait :legends_unlock do
      name { 'Legends Unlock' }
    end
  end
end

