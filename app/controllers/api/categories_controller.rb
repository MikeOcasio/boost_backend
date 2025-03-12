module Api
  class CategoriesController < ApplicationController
    # Set the category instance variable for actions that require it
    before_action :set_category, only: %i[show products update destroy]

    # GET /categories
    # List all categories.
    def index
      # Retrieve all categories from the database
      @categories = Category.all
      # Render the categories in JSON format
      render json: @categories
    end

    # GET /categories/:id
    # Show a specific category based on the provided ID.
    def show
      # Render the specified category in JSON format
      render json: @category
    end

    # GET /categories/:id/products
    # Get all products for a specific category
    def products
      products = @category.products

      if products.any?
        render json: products.as_json(include: { platforms: { only: :id }, category: { only: %i[id name description] } }),
               status: :ok
      else
        render json: { message: 'No products found for this category' }, status: :not_found
      end
    end

    # POST /categories
    # Create a new category.
    def create
      # Handle image uploads
      uploaded_image = (upload_to_s3(params[:category][:image]) if params[:category][:image].present? && params[:category][:remove_image] != 'true')

      uploaded_bg_image = (upload_to_s3(params[:category][:bg_image]) if params[:category][:bg_image].present? && params[:category][:remove_bg_image] != 'true')

      @category = Category.new(category_params)

      # Assign the uploaded images if they exist
      @category.image = uploaded_image if uploaded_image
      @category.bg_image = uploaded_bg_image if uploaded_bg_image

      if @category.save
        render json: @category, status: :created
      else
        render json: @category.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /categories/:id
    # Update an existing category based on the provided ID.
    def update
      # Store old image URLs before updating
      old_image_url = @category.image
      old_bg_image_url = @category.bg_image

      # Handle image update logic
      if params[:category][:image].present?
        uploaded_image = upload_to_s3(params[:category][:image])
        delete_from_s3(old_image_url) if old_image_url.present?
        @category.image = uploaded_image
      elsif params[:category][:remove_image] == 'true'
        delete_from_s3(old_image_url) if old_image_url.present?
        @category.image = nil
      end

      # Handle background image update logic
      if params[:category][:bg_image].present?
        uploaded_bg_image = upload_to_s3(params[:category][:bg_image])
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
        @category.bg_image = uploaded_bg_image
      elsif params[:category][:remove_bg_image] == 'true'
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
        @category.bg_image = nil
      end

      if @category.update(category_params.except(:image, :bg_image, :remove_image, :remove_bg_image))
        render json: @category
      else
        render json: @category.errors, status: :unprocessable_entity
      end
    end

    # DELETE /categories/:id
    # Delete a specific category based on the provided ID.
    def destroy
      # Delete images from S3 before destroying the category
      delete_from_s3(@category.image) if @category.image.present?
      delete_from_s3(@category.bg_image) if @category.bg_image.present?

      @category.destroy
      head :no_content
    end

    private

    # Set the category instance variable for the actions that require it
    # This method is used before show, update, and destroy actions
    def set_category
      @category = Category.find(params[:id])
    end

    # Define strong parameters for creating and updating categories
    # Ensures only permitted attributes are used
    def category_params
      params.require(:category).permit(
        :name,
        :description,
        :is_active,
        :image,
        :bg_image,
        :remove_image,
        :remove_bg_image
      )
    end

    def upload_to_s3(file)
      # Return existing S3 URL if that's what was passed
      return file if file.is_a?(String) && file.match?(%r{^https?://.*\.amazonaws\.com/})

      if file.is_a?(ActionDispatch::Http::UploadedFile)
        obj = S3_BUCKET.object("categories/#{file.original_filename}")
        obj.upload_file(file.tempfile, content_type: 'image/jpeg')
        obj.public_url
      elsif file.is_a?(String) && file.start_with?('data:image/')
        # Handle base64 encoded images
        base64_data = file.split(',')[1]
        decoded_data = Base64.decode64(base64_data)
        filename = "categories/#{SecureRandom.uuid}.jpeg"

        Tempfile.create(['category_image', '.jpeg']) do |temp_file|
          temp_file.binmode
          temp_file.write(decoded_data)
          temp_file.rewind

          obj = S3_BUCKET.object(filename)
          obj.upload_file(temp_file, content_type: 'image/jpeg')
          return obj.public_url
        end
      else
        raise ArgumentError,
              "Expected an UploadedFile, base64 string, or S3 URL, got #{file.class.name}"
      end
    end

    def delete_from_s3(file_url)
      return if file_url.blank?

      file_key = URI.parse(file_url).path[1..]
      obj = S3_BUCKET.object(file_key)
      obj.delete if obj.exists?
    end
  end
end
