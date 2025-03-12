require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:users_categories) }
    it { is_expected.to have_many(:users).through(:users_categories) }
    it { is_expected.to have_many(:products) }
  end

  describe 'attributes' do
    it 'can have an image' do
      category = create(:category)
      expect(category).to respond_to(:image)
    end

    it 'can have a background image' do
      category = create(:category)
      expect(category).to respond_to(:bg_image)
    end
  end
end
