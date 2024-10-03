module Api
  class ProductAttributeCategoriesController < ApplicationController
    before_action :set_product_attribute_category, only: [:show, :update, :destroy, :products]

    # GET /api/product_attribute_categories
    def index
      @product_attribute_categories = ProductAttributeCategory.all
      render json: @product_attribute_categories
    end

    # GET /api/product_attribute_categories/:id
    def show
      render json: @product_attribute_category
    end

    # POST /api/product_attribute_categories
    def create
      @product_attribute_category = ProductAttributeCategory.new(product_attribute_category_params)

      if @product_attribute_category.save
        render json: @product_attribute_category, status: :created
      else
        render json: @product_attribute_category.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /api/product_attribute_categories/:id
    def update
      if @product_attribute_category.update(product_attribute_category_params)
        render json: @product_attribute_category
      else
        render json: @product_attribute_category.errors, status: :unprocessable_entity
      end
    end

    # DELETE /api/product_attribute_categories/:id
    def destroy
      begin
        if @product_attribute_category.destroy
          render json: { message: 'Successfully deleted' }, status: :ok
        else
          render json: { message: 'Failed to delete due to validation errors' }, status: :unprocessable_entity
        end
      rescue => e
        # Log the error message for debugging purposes
        Rails.logger.error("Failed to delete product attribute category: #{e.message}")

        # Send the error message back to the frontend
        render json: { message: "Server error 500: #{e.message}" }, status: :internal_server_error
      end
    end

    # GET /api/product_attribute_categories/:id/products
    def products
      if @product_attribute_category
        products = @product_attribute_category.products
        render json: products, status: :ok
      else
        render json: { error: "Product Attribute Category not found" }, status: :not_found
      end
    end


    private

    def set_product_attribute_category
      @product_attribute_category = ProductAttributeCategory.find_by(id: params[:id])
      Rails.logger.info("Product Attribute Category found: #{@product_attribute_category.inspect}")
    end

    def product_attribute_category_params
      params.require(:product_attribute_category).permit(:name)
    end
  end
end
