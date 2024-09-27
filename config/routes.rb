# config/routes.rb

Rails.application.routes.draw do
  # Define a root route that returns a simple response or redirect
  root to: 'application#health_check'

  namespace :api do
    # User authentication routes using Devise
    devise_for :users, skip: [:sessions, :registrations]
    post '/login', to: 'users#login'                     # Log in a user
    get '/current_user', to: 'users#show_current_user'  # Retrieve the current logged-in user

    # Users routes with member actions
    resources :users do
      member do
        get :platforms           # Get platforms associated with the user
        post :add_platform       # Add a platform to the user
        delete :remove_platform  # Remove a platform from the user
      end
      collection do
        get :skillmasters        # Get users with the 'skillmaster' role
      end
    end

    # Platforms routes with member actions
    resources :platforms do
      member do
        get :products            # Get products associated with the platform
        post :add_product        # Add a product to the platform
        delete :remove_product   # Remove a product from the platform
      end
    end

    # Products routes with member actions
    resources :products do
      collection do
        get 'by_platform/:platform_id', to: 'products#by_platform'  # Get products by platform ID
      end

      member do
        get :platforms          # Get platforms associated with the product
        post :add_platform      # Add a platform to the product
        delete :remove_platform  # Remove a platform from the product
      end
    end


    # Resources for product attribute categories
    resources :product_attribute_categories

    # Resources for categories with limited actions
    resources :categories, only: [:index, :show, :create, :update, :destroy]

    # Resources for files management
    resources :files, only: [:index, :create, :destroy]

    # Resources for orders management
    resources :orders do
      collection do
        get :graveyard_orders    # Get graveyard orders
      end
      member do
        patch :pick_up_order     # Mark order as picked up
      end
    end
  end

  # CSRF token route for frontend usage
  get '/csrf_token', to: 'application#csrf_token'

  # Routes for secure data management
  get '/generate_symmetric_key', to: 'secure_data#generate_symmetric_key'
  get '/generate_asymmetric_key_pair', to: 'secure_data#generate_asymmetric_key_pair'
  post '/encrypt_data', to: 'secure_data#encrypt_data'
  post '/encrypt_symmetric_key', to: 'secure_data#encrypt_symmetric_key'
end
