module Api
  class PlatformsController < ApplicationController
    before_action :set_platform, only: [:update, :destroy]


    # GET /api/platforms
    def index
      @platforms = Platform.all
      render json: @platforms
    end

    # POST /api/platforms
    def create
      @platform = Platform.new(platform_params)
      if @platform.save
        render json: @platform, status: :created
      else
        render json: @platform.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /api/platforms/:id
    def update
      if @platform.update(platform_params)
        render json: @platform
      else
        render json: @platform.errors, status: :unprocessable_entity
      end
    end

    # DELETE /api/platforms/:id
    def destroy
      @platform.destroy
      head :no_content
    end

    # GET /api/platforms/:id/products
    # This action retrieves all products associated with a specific platform
    def products
      @platform = Platform.find(params[:id])
      render json: @platform.products
    end

    # POST /api/platforms/:id/products
    # This action associates a product with a platform
    def add_product
      @platform = Platform.find(params[:id])
      product = Product.find(params[:product_id])
      @platform.products << product unless @platform.products.include?(product)

      render json: @platform, status: :created
    end

    # DELETE /api/platforms/:id/products/:product_id
    # This action disassociates a product from a platform
    def remove_product
      @platform = Platform.find(params[:id])
      product = Product.find(params[:product_id])
      @platform.products.delete(product)

      head :no_content
    end

    private

    def set_platform
      @platform = Platform.find(params[:id])
    end

    def platform_params
      params.require(:platform).permit(:name)
    end
  end
end
