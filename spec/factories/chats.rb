FactoryBot.define do
  factory :chat do
    chat_type { 'direct' }
    status { 'active' }
    active { true }
    broadcast { false }
    title { nil }
    ticket_number { nil }

    association :initiator, factory: :user
    association :recipient, factory: :user, role: 'skillmaster'

    trait :support do
      chat_type { 'support' }
      association :initiator, factory: :user, role: 'customer'
      association :recipient, factory: :user, role: 'admin'
      after(:build) do |chat|
        chat.ticket_number ||= "TICKET-#{Time.current.to_i}-#{SecureRandom.hex(4).upcase}"
      end
    end

    trait :group do
      chat_type { 'group' }
      association :initiator, factory: :user, role: 'admin'

      after(:build) do |chat|
        # Create admin participants before validation
        admin1 = create(:user, role: 'admin')
        admin2 = create(:user, role: 'admin')

        chat.chat_participants.build(user: admin1)
        chat.chat_participants.build(user: admin2)
        chat.chat_participants.build(user: chat.initiator)
      end
    end

    trait :broadcast do
      broadcast { true }
      title { "Broadcast Message #{Time.current.to_i}" }
    end

    trait :archived do
      status { 'archived' }
      active { false }
    end

    trait :with_order do
      association :order
    end
  end
end
