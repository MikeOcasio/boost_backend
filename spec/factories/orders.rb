FactoryBot.define do
  factory :order do
    user
    platform_credential
    promotion
    state { :open }
    assigned_skill_master_id { nil }
    internal_id { SecureRandom.hex(5) }
    price { 100.0 }
    tax { 10.0 }
    total_price { price + tax }
    platform { create(:platform) } # Assuming platform is another model you have
    selected_level { 1 }
    dynamic_price { 120.0 }
    promo_data { { discount: 10, code: 'DISCOUNT10' }.to_json }

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
  end
end
