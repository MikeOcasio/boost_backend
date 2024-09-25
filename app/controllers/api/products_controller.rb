module Api
  class ProductsController < ApplicationController
    # Ensure the product is set before actions that require it
    before_action :set_product, only: [:show, :update, :destroy]

    #! Remove this line once login is implemented
    skip_before_action :verify_authenticity_token

    # GET /products
    # List all products
    def index
      # Retrieve all products from the database
      @products = Product.all
      # Render the list of products in JSON format
      render json: @products
    end

    # GET /products/:id
    # Show a specific product based on the provided ID
    def show
      # Render the details of a single product in JSON format
      render json: @product
    end

    # POST /products
    # Create a new product
    def create
      # Upload images to S3 and get their URLs
      uploaded_image = params[:image] ? upload_to_s3(params[:image]) : nil
      uploaded_bg_image = params[:bg_image] ? upload_to_s3(params[:bg_image]) : nil

      # Initialize a new product with the provided parameters
      @product = Product.new(product_params)
      @product.image = uploaded_image if uploaded_image
      @product.bg_image = uploaded_bg_image if uploaded_bg_image

      # Attempt to save the new product to the database
      if @product.save
        # If successful, render the created product in JSON format with a created status
        render json: @product, status: :created
      else
        # If there are validation errors, render the errors in JSON format with an unprocessable entity status
        render json: @product.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /products/:id
    # Update a specific product based on the provided ID
    def update
      # Upload images to S3 and get their URLs if provided
      uploaded_image = params[:image] ? upload_to_s3(params[:image]) : nil
      uploaded_bg_image = params[:bg_image] ? upload_to_s3(params[:bg_image]) : nil

      # Attempt to update the product with the provided parameters
      if @product.update(product_params)
        @product.image = uploaded_image if uploaded_image
        @product.bg_image = uploaded_bg_image if uploaded_bg_image
        @product.save # Save changes to the product if images were uploaded

        # If successful, render the updated product in JSON format with an OK status
        render json: @product, status: :ok
      else
        # If there are validation errors, render the errors in JSON format with an unprocessable entity status
        render json: @product.errors, status: :unprocessable_entity
      end
    end

    # DELETE /products/:id
    # Delete a specific product based on the provided ID
    def destroy
      # Destroy the product from the database
      @product.destroy
      # Return no content status to indicate successful deletion
      head :no_content
    end

    private

    # Set the product instance variable for actions that require it
    def set_product
      # Find the product by ID
      @product = Product.find(params[:id])
    end

    # Permit only the trusted parameters for creating or updating products
    def product_params
      params.require(:product).permit(:name, :description, :price, :category_id, :product_attribute_category_id, :is_priority, :platform, :is_active, :most_popular, :tag_line, :primary_color, :secondary_color, features: [])
    end

    # Upload a file to S3 and return the URL
    def upload_to_s3(file)
      obj = S3_BUCKET.object("products/#{file.original_filename}")
      obj.upload_file(file.tempfile)
      obj.public_url # Return the public URL of the uploaded file
    end
  end
end
