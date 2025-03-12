module Api
  class ProductsController < ApplicationController
    before_action :set_product, only: %i[show update destroy platforms add_platform remove_platform]
    after_action :clear_cache, only: %i[create update destroy]

    # GET /products
    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 12
      get_all = ActiveModel::Type::Boolean.new.cast(params[:get_all])
      status = params[:status]
      search_query = params[:search]&.downcase
      category_id = params[:category_id]
      platform_id = params[:platform_id]
      attribute_id = params[:attribute_id]

      cache_key = if search_query.present? || category_id.present? || platform_id.present? || attribute_id.present?
                    "products_#{search_query}_status_#{status}_cat_#{category_id}_plat_#{platform_id}_attr_#{attribute_id}_page_#{page}_per_#{per_page}"
                  elsif get_all
                    "all_products_page_#{page}_per_#{per_page}"
                  elsif status == 'inactive'
                    "inactive_products_page_#{page}_per_#{per_page}"
                  else
                    "active_products_page_#{page}_per_#{per_page}"
                  end

      @products = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        products = Product.includes(
          :category,
          :platforms,
          :prod_attr_cats,
          { children: %i[category platforms prod_attr_cats] }
        ).joins(:category)
                          .where(parent_id: nil) # Only get parent products

        # Apply search if present
        if search_query.present?
          products = products.where('LOWER(products.name) LIKE ? OR LOWER(products.description) LIKE ?',
                                    "%#{search_query}%", "%#{search_query}%")
        end

        # Filter by category
        products = products.where(category_id: category_id) if category_id.present?

        # Filter by platform
        products = products.joins(:platforms).where(platforms: { id: platform_id }) if platform_id.present?

        # Filter by product attribute
        products = products.joins(:prod_attr_cats).where(prod_attr_cats: { id: attribute_id }) if attribute_id.present?

        # Apply status filters
        unless get_all
          case status
          when 'inactive'
            products = products.where(is_active: false)
          when 'active', nil
            products = products.where(categories: { is_active: true })
                               .where(is_active: true)
          end
        end

        products = products.distinct.page(page).per(per_page)
        product_map = products.index_by(&:id)

        {
          products: products.map { |product| build_product_json(product, product_map) },
          meta: {
            current_page: products.current_page,
            total_pages: products.total_pages,
            total_count: products.total_count,
            per_page: products.limit_value,
            filter_status: status || 'active',
            search_query: search_query,
            category_id: category_id,
            platform_id: platform_id,
            attribute_id: attribute_id
          }
        }
      end

      render json: @products, status: :ok
    end

    # GET /products/:id
    def show
      @product = Product.includes(:platforms, :category, :prod_attr_cats, :children).find(params[:id])

      render json: recursive_json(@product)
    end

    def by_platform
      platform_id = params[:platform_id]
      platform = Platform.find_by(id: platform_id)

      # Return an error if the platform doesn't exist
      return render json: { message: 'Platform not found' }, status: :not_found unless platform

      # Find products that are associated with the given platform
      @products = Product.joins(:platforms).where(platforms: { id: platform_id })

      # If products are found, render them using the recursive_json method
      if @products.any?
        render json: @products.map { |product| recursive_json(product) }, status: :ok
      else
        # If no products found, return a not found message
        render json: { message: 'No products found for this platform' }, status: :not_found
      end
    end

    def by_category
      @category = Category.find(params[:category_id])
      page = params[:page] || 1
      per_page = params[:per_page] || 12

      @products = @category.products
                           .includes(:platforms, :category, :prod_attr_cats,
                                     { children: %i[platforms category prod_attr_cats] })
                           .where('products.parent_id IS NULL OR EXISTS (SELECT 1 FROM products children WHERE children.parent_id = products.id)')
                           .distinct
                           .page(page).per(per_page)

      render json: {
        products: @products.map { |product| recursive_json(product) },
        meta: {
          current_page: @products.current_page,
          total_pages: @products.total_pages,
          total_count: @products.total_count,
          per_page: @products.limit_value
        }
      }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Category not found' }, status: :not_found
    end

    # POST /products
    def create
      # Handle image upload if provided
      uploaded_image = if params[:product][:image].present? && params[:product][:remove_image] != 'true'
                         upload_to_s3(params[:product][:image])
                       end

      # Handle background image upload if provided and remove_bg_image flag is false
      uploaded_bg_image = if params[:product][:bg_image].present? && params[:product][:remove_bg_image] != 'true'
                            upload_to_s3(params[:product][:bg_image])
                          end

      # Create a new product with the provided attributes, excluding platform_ids for now
      @product = Product.new(product_params.except(:platform_ids))

      # Assign the uploaded images if they exist
      @product.image = uploaded_image if uploaded_image
      @product.bg_image = uploaded_bg_image if uploaded_bg_image

      # Assign platforms if provided
      @product.platform_ids = params[:platform_ids] if params[:platform_ids].present?

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
            platforms: { only: %i[id name] },
            category: { only: %i[id name description] },
            prod_attr_cats: { only: %i[id name] }
          }
        ), status: :created
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end

    # GET api/products/id
    def update
      # Store old image URLs before updating
      old_image_url = @product.image
      old_bg_image_url = @product.bg_image

      # Assign platforms if provided
      @product.platform_ids = params[:product][:platform_ids] if params[:product][:platform_ids].present?

      # Handle image update logic
      if params[:product][:image].present?
        if old_image_url.present? && old_image_url.start_with?('data:image/') # Check if old image is Base64
          # If old image is Base64, simply set the new image
          @product.image = upload_to_s3(params[:product][:image])
          @product.save
        elsif params[:product][:image].start_with?('data:image/')
          # Handle new image upload
          uploaded_image = upload_to_s3(params[:product][:image])
          delete_from_s3(old_image_url) if old_image_url.present?
          @product.image = uploaded_image # Check for Base64
        # Upload the Base64 image to S3
        elsif params[:product][:image].present? && params[:product][:image] != old_image_url
          # If the image is a URL, upload it to S3
          uploaded_image = upload_to_s3(params[:product][:image])
          delete_from_s3(old_image_url) if old_image_url.present?
          @product.image = uploaded_image
        end
      elsif ActiveModel::Type::Boolean.new.cast(params[:product][:remove_image]) || params[:product][:image].nil?
        # If the remove_image flag is true, delete the old image
        delete_from_s3(old_image_url) if old_image_url.present? && !old_image_url.start_with?('data:image/')
        @product.image = nil
      end

      # Handle background image update logic
      if params[:product][:bg_image].present?
        if old_bg_image_url.present? && old_bg_image_url.start_with?('data:image/') # Check if old bg image is Base64
          # If old background image is Base64, simply set the new bg image
          @product.bg_image = upload_to_s3(params[:product][:bg_image])
        elsif params[:product][:bg_image].start_with?('data:image/')
          # Handle new background image upload
          uploaded_bg_image = upload_to_s3(params[:product][:bg_image])
          delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
          @product.bg_image = uploaded_bg_image # Check for Base64
        # Upload the Base64 background image to S3
        elsif params[:product][:bg_image].present? && params[:product][:bg_image] != old_bg_image_url
          # If the background image is a URL, upload it to S3
          uploaded_bg_image = upload_to_s3(params[:product][:bg_image])
          delete_from_s3(old_bg_image_url) if old_bg_image_url.present?
          @product.bg_image = uploaded_bg_image
        end
      elsif ActiveModel::Type::Boolean.new.cast(params[:product][:remove_bg_image]) || params[:product][:bg_image].nil?
        # If the remove_bg_image flag is true, delete the old background image
        delete_from_s3(old_bg_image_url) if old_bg_image_url.present? && !old_bg_image_url.start_with?('data:image/')
        @product.bg_image = nil
      end

      @product.save

      # Update the product without affecting images if not specified
      if @product.update(product_params.except(:image, :bg_image, :platform_ids))
        render json: @product.as_json(
          include: {
            platforms: { only: %i[id name] },
            category: { only: %i[id name description] },
            prod_attr_cats: { only: %i[id name] } # Include both IDs and names of prod_attr_cats
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

    def recursive_json(product)
      {
        id: product.id,
        name: product.name,
        description: product.description,
        price: product.price,
        image: product.image, # Include image if necessary
        created_at: product.created_at,
        updated_at: product.updated_at,
        is_priority: product.is_priority,
        tax: product.tax,
        is_active: product.is_active,
        most_popular: product.most_popular,
        tag_line: product.tag_line,
        bg_image: product.bg_image,
        primary_color: product.primary_color,
        secondary_color: product.secondary_color,
        features: product.features,
        category_id: product.category_id,
        is_dropdown: product.is_dropdown,
        dropdown_options: product.dropdown_options,
        is_slider: product.is_slider,
        slider_range: product.slider_range,
        parent_id: product.parent_id,
        parent_name: product.parent&.name,

        # Include associated platforms, categories, and prod_attr_cats
        platforms: product.platforms.as_json(only: %i[id name]),
        category: product.category.as_json(only: %i[id name description is_active]),
        prod_attr_cats: product.prod_attr_cats.as_json(only: %i[id name]),

        # Recursively include children (if any)
        children: product.children.map { |child| recursive_json(child) }
      }
    end

    def delete_from_s3(file_url)
      return if file_url.blank?

      # Extract the object key from the URL
      file_key = URI.parse(file_url).path[1..] # Strip leading "/"

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
        :parent_id,
        :category_id,
        :is_dropdown,
        :is_slider,
        slider_range: [], # Allows an array of slider range values
        dropdown_options: [], # Allows an array of dropdown options
        features: [], # Allows an array of features
        platform_ids: [],     # Assuming platform_ids is an array
        prod_attr_cat_ids: [] # Assuming prod_attr_cat_ids is an array
      )
    end

    def clear_cache
      Rails.cache.delete_matched('active_products_page_*')
      Rails.cache.delete_matched('inactive_products_page_*')
      Rails.cache.delete_matched('all_products_page_*')
      Rails.cache.delete_matched('products_*')
    end

    def upload_to_s3(file)
      # If the file is already a valid S3 URL, return it directly
      if file.is_a?(String) && file.match?(%r{^https?://.*\.amazonaws\.com/})
        return file
      end

      if file.is_a?(ActionDispatch::Http::UploadedFile)
        obj = S3_BUCKET.object("products/#{file.original_filename}")
        obj.upload_file(file.tempfile, content_type: 'image/jpeg')
        obj.public_url
      elsif file.is_a?(String) && file.start_with?('data:image/')
        # Extract the base64 part from the data URL
        base64_data = file.split(',')[1]
        # Decode the base64 data
        decoded_data = Base64.decode64(base64_data)

        # Generate a unique filename (you can adjust the logic as needed)
        filename = "products/#{SecureRandom.uuid}.jpeg" # Change the extension based on the image type if needed

        # Create a temporary file to upload
        Tempfile.create(['product_image', '.jpeg']) do |temp_file|
          temp_file.binmode
          temp_file.write(decoded_data)
          temp_file.rewind

          # Upload the temporary file to S3
          obj = S3_BUCKET.object(filename)
          obj.upload_file(temp_file, content_type: 'image/jpeg')

          return obj.public_url
        end
      else
        raise ArgumentError,
              "Expected an instance of ActionDispatch::Http::UploadedFile, a base64 string, or an S3 URL, got #{file.class.name}"
      end
    end

    def build_product_json(product, product_map)
      {
        id: product.id,
        name: product.name,
        description: product.description,
        price: product.price,
        image: product.image,
        created_at: product.created_at,
        updated_at: product.updated_at,
        is_priority: product.is_priority,
        tax: product.tax,
        is_active: product.is_active,
        most_popular: product.most_popular,
        tag_line: product.tag_line,
        bg_image: product.bg_image,
        primary_color: product.primary_color,
        secondary_color: product.secondary_color,
        features: product.features,
        category_id: product.category_id,
        is_dropdown: product.is_dropdown,
        dropdown_options: product.dropdown_options,
        is_slider: product.is_slider,
        slider_range: product.slider_range,
        parent_id: product.parent_id,

        # Associated data
        platforms: product.platforms.map { |p| p.slice(:id, :name) },
        category: product.category&.slice(:id, :name, :description, :is_active),
        prod_attr_cats: product.prod_attr_cats.map { |a| a.slice(:id, :name) },
        children: product.children.map do |child|
          build_product_json(child, product_map) if child
        end.compact
      }
    end
  end
end
