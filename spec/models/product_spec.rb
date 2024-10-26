# spec/models/product_spec.rb
require 'rails_helper'

RSpec.describe Product, type: :model do
  # Associations
  it { is_expected.to belong_to(:category) }
  it { is_expected.to belong_to(:product_attribute_category) }
  it { is_expected.to have_many(:orders).through(:order_products) }
  it { is_expected.to have_many(:carts) }
  it { is_expected.to have_many(:promotions).through(:product_promotions) }

  # Validations
  it { is_expected.to validate_presence_of(:platform) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:price) }

  # Scopes
  describe '.by_platform' do
    let!(:product1) { create(:product, platform: 'PS5') }
    let!(:product2) { create(:product, platform: 'Xbox') }
    let!(:product3) { create(:product, platform: 'PC') }

    it 'returns products for a specific platform' do
      expect(Product.by_platform('PS5')).to include(product1)
      expect(Product.by_platform('PS5')).not_to include(product2, product3)
    end
  end

  # Instance Methods
  describe '#to_s' do
    it 'returns product name and price as a formatted string' do
      product = build(:product, name: 'Awesome Product', price: 99.99)
      expect(product.to_s).to eq('Awesome Product - $99.99')
    end
  end
end
