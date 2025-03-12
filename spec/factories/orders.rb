FactoryBot.define do
  factory :order do
    user
    platform_credential
    assigned_skill_master_id { create(:user, role: 'skillmaster').id }

    state { 'pending' }
    total_price { 100.0 }
    price { 90.0 }
    tax { 10.0 }
    platform { platform_credential&.platform&.name || 'PC' }
    selected_level { 'standard' }
    dynamic_price { false }
    points { 0 }
    internal_id { "ORD-#{Time.current.to_i}" }
    promo_data { {} }
    order_data { {} }

    trait :with_promotion do
      promotion
    end

    trait :with_referral do
      referral_skillmaster_id { create(:user, role: 'skillmaster').id }
    end

    trait :pending do
      state { 'pending' }
    end

    trait :assigned do
      state { 'assigned' }
    end

    trait :in_progress do
      state { 'in_progress' }
    end

    trait :completed do
      state { 'completed' }
    end

    trait :cancelled do
      state { 'cancelled' }
    end

    trait :disputed do
      state { 'disputed' }
    end

    trait :delayed do
      state { 'delayed' }
    end

    trait :with_products do
      after(:create) do |order|
        create_list(:order_product, 2, order: order)
      end
    end

    after(:build) do |order|
      # Ensure platform_credential is assigned if missing and user is present
      order.assign_platform_credentials if order.platform_credential.nil? && order.user.present?
    end

    # Factory for creating associated models
    factory :order_with_products do
      transient do
        products_count { 3 }
      end

      after(:create) do |order, evaluator|
        create_list(:order_product, evaluator.products_count, order: order)
      end
    end

    # Alternative approach using after callbacks
    trait :force_completed do
      after(:build) do |order|
        order.state = 'completed'
      end
    end
  end
end
