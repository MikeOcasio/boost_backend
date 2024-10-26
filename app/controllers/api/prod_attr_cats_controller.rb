module Api
  class ProdAttrCatsController < ApplicationController
    before_action :set_prod_attr_cat, only: %i[show update destroy products]

    # GET /api/prod_attr_cats
    def index
      @prod_attr_cats = ProdAttrCat.all
      render json: @prod_attr_cats
    end

    # GET /api/prod_attr_cats/:id
    def show
      render json: @prod_attr_cat
    end

    # POST /api/prod_attr_cats
    def create
      @prod_attr_cat = ProdAttrCat.new(prod_attr_cat_params)

      if @prod_attr_cat.save
        render json: @prod_attr_cat, status: :created
      else
        render json: @prod_attr_cat.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /api/prod_attr_cats/:id
    def update
      if @prod_attr_cat.update(prod_attr_cat_params)
        render json: @prod_attr_cat
      else
        render json: @prod_attr_cat.errors, status: :unprocessable_entity
      end
    end

    # DELETE /api/prod_attr_cats/:id
    def destroy
      if @prod_attr_cat.destroy
        render json: { message: 'Successfully deleted' }, status: :ok
      else
        render json: { message: 'Failed to delete due to validation errors' }, status: :unprocessable_entity
      end
    rescue StandardError => e
      # Log the error message for debugging purposes
      Rails.logger.error("Failed to delete product attribute category: #{e.message}")

      # Send the error message back to the frontend
      render json: { message: "Server error 500: #{e.message}" }, status: :internal_server_error
    end

    # GET /api/prod_attr_cats/:id/products
    def products
      if @prod_attr_cat
        products = @prod_attr_cat.products
        render json: products, status: :ok
      else
        render json: { error: 'Product Attribute Category not found' }, status: :not_found
      end
    end

    private

    def set_prod_attr_cat
      @prod_attr_cat = ProdAttrCat.find_by(id: params[:id])
      Rails.logger.info("Product Attribute Category found: #{@prod_attr_cat.inspect}")
    end

    def prod_attr_cat_params
      params.require(:prod_attr_cat).permit(:name)
    end
  end
end
