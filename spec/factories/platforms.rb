FactoryBot.define do
  factory :platform do
    name { Faker::Game.platform }
    has_sub_platforms { false }
  end
end
