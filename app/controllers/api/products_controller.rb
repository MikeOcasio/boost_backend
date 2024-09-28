module Api
  class ProductsController < ApplicationController
    before_action :set_product, only: [:show, :update, :destroy, :platforms, :add_platform, :remove_platform]

    #! Remove this line once login is implemented
    skip_before_action :verify_authenticity_token

    # GET /products
    def index
      @products = Product.all
      render json: @products
    end

    def by_platform
      platform_id = params[:platform_id]
      platform = Platform.find_by(id: platform_id)

      unless platform
        return render json: { message: "Platform not found" }, status: :not_found
      end

      @products = Product.joins(:platforms).where(platforms: { id: platform_id })

      if @products.any?
        render json: @product.as_json(include: { platforms: { only: :id } }), status: :ok
      else
        render json: { message: "No products found for this platform" }, status: :not_found
      end
    end

    # GET /products/:id
    def show
      render json: @product.as_json(include: { platforms: { only: :id } })
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
        render json: @product.as_json(include: { platforms: { only: :id } }), status: :created
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end


    # PATCH/PUT /products/:id
    def update
      uploaded_image = params[:image] ? upload_to_s3(params[:image]) : nil
      uploaded_bg_image = params[:bg_image] ? upload_to_s3(params[:bg_image]) : nil

      if params[:platform_ids].present?
        @product.platforms = Platform.where(id: params[:platform_ids]) # Assign platforms
      end

      if @product.update(product_params.except(:platform_ids))
        @product.image = uploaded_image if uploaded_image
        @product.bg_image = uploaded_bg_image if uploaded_bg_image
        render json: @product.as_json(include: { platforms: { only: :id } }), status: :ok
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

private

    def delete_from_s3(file_url)
      # Extract the object key from the URL
      file_key = file_url.split('/').last

      # Delete the object from S3
      obj = S3_BUCKET.object("products/#{file_key}")
      obj.delete
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
      params.require(:product).permit(:name, :description, :price, :category_id, :product_attribute_category_id, :is_priority, :is_active, :most_popular, :tax, :tag_line, :primary_color, :secondary_color, features: [], platform_ids: [])
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
