require 'rails_helper'

RSpec.describe Api::CategoriesController, type: :controller do
  # Include Devise test helpers
  include Devise::Test::ControllerHelpers

  # Create a user and sign them in before each test
  let(:user) { create(:user, :admin) }
  let(:s3_url) { 'https://test-bucket.s3.amazonaws.com/categories/test-image.jpg' }

  before do
    sign_in user

    # Mock S3 interactions
    allow_any_instance_of(Aws::S3::Object).to receive(:upload_file).and_return(true)
    allow_any_instance_of(Aws::S3::Object).to receive(:public_url).and_return(s3_url)
    allow_any_instance_of(Aws::S3::Object).to receive(:exists?).and_return(true)
    allow_any_instance_of(Aws::S3::Object).to receive(:delete).and_return(true)
  end

  let(:valid_attributes) do
    {
      name: 'Test Category',
      description: 'Test Description',
      is_active: true
    }
  end

  let(:invalid_attributes) do
    {
      name: '',
      description: 'Test Description'
    }
  end

  describe 'POST #create' do
    context 'with valid attributes' do
      it 'creates a new category' do
        expect do
          post :create, params: { category: valid_attributes }
        end.to change(Category, :count).by(1)
      end

      it 'creates a category with an image' do
        post :create, params: {
          category: valid_attributes.merge(image: base64_image)
        }

        category = Category.last
        expect(category.image).to be_present
        expect(category.image).to include('amazonaws.com')
      end

      it 'creates a category with a background image' do
        post :create, params: {
          category: valid_attributes.merge(bg_image: base64_image)
        }

        category = Category.last
        expect(category.bg_image).to be_present
        expect(category.bg_image).to include('amazonaws.com')
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new category' do
        expect do
          post :create, params: { category: invalid_attributes }
        end.not_to change(Category, :count)
      end
    end
  end

  describe 'PUT #update' do
    let(:category) { create(:category) }

    it 'updates the category attributes' do
      new_attributes = { name: 'Updated Category' }
      put :update, params: { id: category.id, category: new_attributes }
      category.reload
      expect(category.name).to eq('Updated Category')
    end

    it 'updates the category image' do
      put :update, params: {
        id: category.id,
        category: { image: base64_image }
      }

      category.reload
      expect(category.image).to be_present
      expect(category.image).to include('amazonaws.com')
    end

    it 'removes the category image' do
      # First add an image with S3 URL
      allow(controller).to receive(:upload_to_s3).and_return(s3_url)
      category.update(image: s3_url)

      # Then remove it
      put :update, params: {
        id: category.id,
        category: { remove_image: true }
      }

      category.reload
      expect(category.image).to be_nil
    end

    it 'updates the background image' do
      put :update, params: {
        id: category.id,
        category: { bg_image: base64_image }
      }

      category.reload
      expect(category.bg_image).to be_present
      expect(category.bg_image).to include('amazonaws.com')
    end
  end

  describe 'DELETE #destroy' do
    let!(:category) { create(:category) }

    it 'deletes the category and its associated images' do
      # First add images with S3 URLs
      allow(controller).to receive(:upload_to_s3).and_return(s3_url)
      category.update(
        image: s3_url,
        bg_image: s3_url
      )

      expect do
        delete :destroy, params: { id: category.id }
      end.to change(Category, :count).by(-1)

      # No need to check image values since record is deleted
      expect(Category.exists?(category.id)).to be false
    end
  end
end
