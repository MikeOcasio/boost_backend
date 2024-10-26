FactoryBot.define do
  factory :bug_report do
    title { 'MyString' }
    description { 'MyText' }
    user { nil }
  end
end
