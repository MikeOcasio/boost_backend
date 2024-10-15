module Api
  class ProductsController < ApplicationController


    before_action :set_product, only: [:show, :update, :destroy, :platforms, :add_platform, :remove_platform]


    # GET /products
    def index
      @products = Product.includes(:category, :platforms).all
      render json: @products.as_json(
        include: {
          platforms: { only: [:id, :name] },
          category: { only: [:id, :name, :description] },
          prod_attr_cats: { only: [:id, :name] }
        }
      )
    end


    # GET /products/:id
    def show
      @product = Product.includes(:platforms, :category).find(params[:id])
      render json: @product.as_json(
        include: {
          platforms: { only: [:id, :name] },
          category: { only: [:id, :name, :description] },
          prod_attr_cats: { only: [:id, :name] }
        }
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
      # Handle image upload if provided
      uploaded_image = params[:image] && params[:remove_image] == 'false' ? upload_to_s3(params[:image]) : nil
      uploaded_bg_image = params[:bg_image] && params[:remove_bg_image] == 'false' ? upload_to_s3(params[:bg_image]) : nil

      # Create a new product with the provided attributes, excluding platform_ids for now
      @product = Product.new(product_params.except(:platform_ids))

      # Assign the uploaded images if they exist
      @product.image = uploaded_image if uploaded_image
      @product.bg_image = uploaded_bg_image if uploaded_bg_image

      # Assign platforms if provided
      if params[:platform_ids].present?
        @product.platforms = Platform.where(id: params[:platform_ids])
      end

      # Assign prod_attr_cats if provided
      if params[:prod_attr_cat_ids].present?
        prod_attr_cats = params[:prod_attr_cat_ids].map do |id|
          ProdAttrCat.find_by(id: id)
        end.compact
        @product.prod_attr_cats = prod_attr_cats
      end

      # Attempt to save the product
      if @product.save
        render json: @product.as_json(
          include: {
            platforms: { only: [:id, :name] },
            category: { only: [:id, :name, :description] },
            prod_attr_cats: { only: [:id, :name] }
          }
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
      if params[:product][:platform_ids].present?
        @product.platform_ids = params[:product][:platform_ids]
      end

      # Handle image update and deletion logic
      if ActiveModel::Type::Boolean.new.cast(params[:remove_image])
        delete_from_s3(old_image_url) if old_image_url.present?
        @product.image = nil
      elsif params[:image].present? && params[:image] != old_image_url
        uploaded_image = upload_to_s3(params[:image])
        delete_from_s3(old_image_url) if old_image_url.present?
        @product.image = uploaded_image
      end

      # Handle background image update and deletion logic
      if ActiveModel::Type::Boolean.new.cast(params[:remove_bg_image])
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
        @product.bg_image = nil
      elsif params[:bg_image].present? && params[:bg_image] != old_bg_image_url
        uploaded_bg_image = upload_to_s3(params[:bg_image])
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
        @product.bg_image = uploaded_bg_image
      end

      # Update the product without affecting images if not specified
      if @product.update(product_params.except(:platform_ids))
        render json: @product.as_json(
          include: {
            platforms: { only: [:id, :name] },
            category: { only: [:id, :name, :description] },
            prod_attr_cats: { only: [:id, :name] }  # Include both IDs and names of prod_attr_cats
          }
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
        :image,
        :bg_image,
        :remove_bg_image,
        :remove_image,
        :is_priority,
        :tax,
        :is_active,
        :most_popular,
        :tag_line,
        :primary_color,
        :secondary_color,
        :category_id,
        features: [],          # Allows an array of features
        platform_ids: [],     # Assuming platform_ids is an array
        prod_attr_cat_ids: [] # Assuming prod_attr_cat_ids is an array
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
