module Api
  class ProductsController < ApplicationController
    before_action :set_product, only: [:show, :update, :destroy]

    #! Remove this line once login is implemented
    skip_before_action :verify_authenticity_token

    def platform_options
      platform_options = Product::PLATFORM_OPTIONS
      render json: platform_options
    end

    # GET /products
    def index
      @products = Product.all
      render json: @products
    end

    # GET /products/:id
    def show
      render json: @product
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
        render json: @product, status: :created
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
        render json: @product, status: :ok
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end



    # DELETE /products/:id
    def destroy
      @product.destroy
      head :no_content
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
      @product = Product.find(params[:id])
    end

    def product_params
      params.require(:product).permit(:name, :description, :price, :category_id, :product_attribute_category_id, :is_priority, :is_active, :most_popular, :tag_line, :primary_color, :secondary_color, features: [], platform_ids: [])
    end

    def upload_to_s3(file)
      if file.is_a?(ActionDispatch::Http::UploadedFile)
        obj = S3_BUCKET.object("products/#{file.original_filename}")
        obj.upload_file(file.tempfile)
        obj.public_url
      else
        raise ArgumentError, "Expected an instance of ActionDispatch::Http::UploadedFile, got #{file.class.name}"
      end
    end
  end
end
