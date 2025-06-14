FactoryBot.define do
  factory :order_rejection do
    order { nil }
    admin_user { nil }
    rejection_type { "MyString" }
    reason { "MyText" }
    rejection_notes { "MyText" }
    created_at { "2025-06-13 22:57:19" }
  end
end
