module Api
  class CategoriesController < ApplicationController
    # Set the category instance variable for actions that require it
    before_action :set_category, only: [:show, :update, :destroy]

    #! Remove this line once login is implemented
    skip_before_action :verify_authenticity_token

    # GET /categories
    # List all categories.
    def index
      # Retrieve all categories from the database
      @categories = Category.all
      # Render the categories in JSON format
      render json: @categories
    end

    # GET /categories/:id
    # Show a specific category based on the provided ID.
    def show
      # Render the specified category in JSON format
      render json: @category
    end

    # POST /categories
    # Create a new category.
    def create
      # Initialize a new category with the provided parameters
      @category = Category.new(category_params)

      # Attempt to save the new category to the database
      if @category.save
        # Return the created category and a status of created
        render json: @category, status: :created
      else
        # Return validation errors and a status of unprocessable entity
        render json: @category.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /categories/:id
    # Update an existing category based on the provided ID.
    def update
      # Attempt to update the category with the provided parameters
      if @category.update(category_params)

        # If the category's is_active attribute is set to false, update associated products
      if @category.is_active == false
        @category.products.update_all(is_active: false)
      end
        # Return the updated category in JSON format
        render json: @category
      else
        # Return validation errors and a status of unprocessable entity
        render json: @category.errors, status: :unprocessable_entity
      end
    end

    # DELETE /categories/:id
    # Delete a specific category based on the provided ID.
    def destroy
      # Delete the category from the database
      @category.destroy
      # Return a no content response
      head :no_content
    end

    private

    # Set the category instance variable for the actions that require it
    # This method is used before show, update, and destroy actions
    def set_category
      @category = Category.find(params[:id])
    end

    # Define strong parameters for creating and updating categories
    # Ensures only permitted attributes are used
    def category_params
      params.require(:category).permit(:name, :description)
    end
  end
end
