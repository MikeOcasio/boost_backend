module Api
  class ProductsController < ApplicationController


    before_action :set_product, only: [:show, :update, :destroy, :platforms, :add_platform, :remove_platform]


    # GET /products
    def index
      @products = Product.includes(:category, :platforms).all
      render json: @products.as_json(
        include: {
          platforms: { only: [:id, :name] },
          category: { only: [:id, :name, :description] }
        },
        methods: [:prod_attr_cat_ids]
      )
    end


    # GET /products/:id
    def show
      @product = Product.includes(:platforms, :category).find(params[:id])
      render json: @product.as_json(
        include: {
          platforms: { only: [:id, :name] },
          category: { only: [:id, :name, :description] }
        },
        methods: [:prod_attr_cat_ids]
      )
    end

    def by_platform
      platform_id = params[:platform_id]
      platform = Platform.find_by(id: platform_id)

      unless platform
        return render json: { message: "Platform not found" }, status: :not_found
      end

      @products = Product.joins(:platforms).where(platforms: { id: platform_id })

      if @products.any?
        render json: @product.as_json(include: { platforms: { only: [:id, :name ] } }), status: :ok
      else
        render json: { message: "No products found for this platform" }, status: :not_found
      end
    end

    # POST /products
    def create
      uploaded_image = params[:image] ? upload_to_s3(params[:image]) : nil
      uploaded_bg_image = params[:bg_image] ? upload_to_s3(params[:bg_image]) : nil

      @product = Product.new(product_params.except(:platform_ids)) # Exclude platform_ids for now
      @product.image = uploaded_image if uploaded_image
      @product.bg_image = uploaded_bg_image if uploaded_bg_image

      if params[:platform_ids].present?
        @product.platforms = Platform.where(id: params[:platform_ids]) # Associate platforms before saving
      end

      if @product.save
        render json: @product.as_json(
          include: { platforms: { only: :id } },
          methods: [:prod_attr_cat_ids]
        ), status: :created
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end


    def update
      # Store old image URLs before updating
      old_image_url = @product.image
      old_bg_image_url = @product.bg_image

      # Assign platforms if provided
      if params[:platform_ids].present?
        @product.platforms = Platform.where(id: params[:platform_ids])
      end

      # Initialize variables for the updated images
      uploaded_image = nil
      uploaded_bg_image = nil

      # Handle image update and deletion logic
      if ActiveModel::Type::Boolean.new.cast(params[:remove_image]) || params[:image].nil?
        delete_from_s3(old_image_url) if old_image_url.present?
        @product.image = nil
      elsif params[:image] && params[:image] != old_image_url
        uploaded_image = upload_to_s3(params[:image])
        delete_from_s3(old_image_url) if old_image_url.present? && uploaded_image.present?
        @product.image = uploaded_image if uploaded_image.present?
      end

      # Handle background image update and deletion logic
      if ActiveModel::Type::Boolean.new.cast(params[:remove_bg_image]) || params[:bg_image].nil?
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
        @product.bg_image = nil
      elsif params[:bg_image] && params[:bg_image] != old_bg_image_url
        uploaded_bg_image = upload_to_s3(params[:bg_image])
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present? && uploaded_bg_image.present?
        @product.bg_image = uploaded_bg_image if uploaded_bg_image.present?
      end

      # Update the product
      if @product.update(product_params.except(:platform_ids))
        render json: @product.as_json(
          include: { platforms: { only: :id } },
          methods: [:prod_attr_cat_ids]
        ), status: :ok
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end




    # DELETE /products/:id
    def destroy
      # Delete images from S3 if they exist
      delete_from_s3(@product.image) if @product.image.present?
      delete_from_s3(@product.bg_image) if @product.bg_image.present?

      # Destroy the product record
      @product.destroy
      head :no_content
    end

    # Helper method to delete from S3
    private

    def delete_from_s3(file_url)
      return if file_url.blank?

      # Extract the object key from the URL
      file_key = URI.parse(file_url).path[1..]  # Strip leading "/"

      # Delete the object from S3
      obj = S3_BUCKET.object(file_key)
      obj.delete if obj.exists?
    end

    # GET /products/:id/platforms
    # Retrieve all platforms associated with a specific product
    def platforms
      render json: @product.platforms
    end

    # POST /products/:id/platforms
    # Associate a platform with a product
    def add_platform
      platform = Platform.find(params[:platform_id])
      @product.platforms << platform unless @product.platforms.include?(platform)

      render json: @product, status: :created
    end

    # DELETE /products/:id/platforms/:platform_id
    # Disassociate a platform from a product
    def remove_platform
      platform = Platform.find(params[:platform_id])
      @product.platforms.delete(platform)

      head :no_content
    end

    private

    def set_product
      @product = Product.find_by(id: params[:id])
      render json: { error: 'Product not found' }, status: :not_found if @product.nil?
    end

    def product_params
      params.require(:product).permit(
        :name,
        :description,
        :price,
        :category_id, # Include this to allow category assignment
        :is_priority,
        :is_active,
        :most_popular,
        :tax,
        :tag_line,
        :primary_color,
        :secondary_color,
        :remove_image,
        features: [],
        platform_ids: [],
        prod_attr_cat_ids: []
      )
    end


    def upload_to_s3(file)
      if file.is_a?(ActionDispatch::Http::UploadedFile)
        obj = S3_BUCKET.object("products/#{file.original_filename}")
        obj.upload_file(file.tempfile)
        obj.public_url
      elsif file.is_a?(String) && file.start_with?('data:image/')
        # Extract the base64 part from the data URL
        base64_data = file.split(',')[1]
        # Decode the base64 data
        decoded_data = Base64.decode64(base64_data)

        # Generate a unique filename (you can adjust the logic as needed)
        filename = "products/#{SecureRandom.uuid}.webp" # Change the extension based on the image type if needed

        # Create a temporary file to upload
        Tempfile.create(['product_image', '.webp']) do |temp_file|
          temp_file.binmode
          temp_file.write(decoded_data)
          temp_file.rewind

          # Upload the temporary file to S3
          obj = S3_BUCKET.object(filename)
          obj.upload_file(temp_file)

          return obj.public_url
        end
      else
        raise ArgumentError, "Expected an instance of ActionDispatch::Http::UploadedFile or a base64 string, got #{file.class.name}"
      end
    end
  end
end
