module Api
  class ProductAttributeCategoriesController < ApplicationController
    before_action :set_product_attribute_category, only: [:show, :update, :destroy]

    #! Remove this line once login is implemented
    skip_before_action :verify_authenticity_token

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
      @product_attribute_category.destroy
      head :no_content
    end

    private

    def set_product_attribute_category
      @product_attribute_category = ProductAttributeCategory.find(params[:id])
    end

    def product_attribute_category_params
      params.require(:product_attribute_category).permit(:name)
    end
  end
end
