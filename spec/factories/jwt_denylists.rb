FactoryBot.define do
  factory :jwt_denylist do
    jti { "MyString" }
    exp { "2024-10-07 19:05:16" }
  end
end
