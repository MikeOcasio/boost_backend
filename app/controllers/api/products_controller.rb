module Api
  class ProductsController < ApplicationController
    # Ensure the product is set before actions that require it
    before_action :set_product, only: [:show, :edit, :update, :destroy]

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

    # GET /products/new
    # Initialize a new product object
    def new
      @product = Product.new
      # This action is typically used to render a form for creating a new product
      # You might render a form view or return a JSON response here
    end

    # POST /products
    # Create a new product
    def create
      # Initialize a new product with the provided parameters
      @product = Product.new(product_params)

      # Attempt to save the new product to the database
      if @product.save
        # If successful, render the created product in JSON format with a created status
        render json: @product, status: :created
      else
        # If there are validation errors, render the errors in JSON format with an unprocessable entity status
        render json: @product.errors, status: :unprocessable_entity
      end
    end

    # GET /products/:id/edit
    # Initialize an existing product for editing
    def edit
      # This action is typically used to render a form for editing an existing product
      # You might render a form view or return a JSON response here
    end

    # PATCH/PUT /products/:id
    # Update a specific product based on the provided ID
    def update
      # Attempt to update the product with the provided parameters
      if @product.update(product_params)
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
    # This method is used before show, edit, update, and destroy actions
    def set_product
      # Find the product by ID
      @product = Product.find(params[:id])
    end

    # Permit only the trusted parameters for creating or updating products
    def product_params
      params.require(:product).permit(:name, :description, :price, :image, :category_id, :product_attribute_category_id, :is_priority, :platform, :is_active, :most_popular, :tag_line, :bg_image, :primary_color, :secondary_color, features: [])
    end

  end
end
