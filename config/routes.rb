Rails.application.routes.draw do
  root to: 'application#health_check'


  ####User Authentication Routes####

  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  Rails.application.routes.draw do
    namespace :users do
      resources :members, path: 'member-data', only: [:index, :create, :show, :update, :destroy] do
        member do
          get :platforms
          post :add_platform
          delete :remove_platform
        end

        # Define the route for retrieving the signed-in user
        collection do
          get :signed_in_user
          get :skillmasters
        end
      end

      # Add the show_skillmaster route outside of the members resources
      get 'members/skillmasters/:id', to: 'members#show_skillmaster', as: :show_skillmaster
    end
  end

   delete 'users/sign_out', to: 'users/sessions#destroy'






  namespace :api do
    # # Users routes
    # resources :users do
    #   member do
    #     get :platforms
    #     post :add_platform
    #     delete :remove_platform
    #   end
    #   collection do
    #     get :skillmasters
    #   end
    # end

    # Platforms routes
    resources :platforms do
      member do
        get :products
        post :add_product
        delete :remove_product
      end
    end

    # Products routes
    resources :products do
      collection do
        get 'by_platforms/:platform_id', to: 'products#by_platform'
      end
      member do
        get :platforms
        post :add_platform
        delete :remove_platform
      end
    end

    # Categories routes
    resources :categories do
      member do
        get :products  # Get products for a specific category
      end
    end

    # Resources for product attribute categories
    resources :product_attribute_categories do
      member do
        get :products  # Route to list products for the specific product attribute category
      end
    end

    # Resources for categories with limited actions
    resources :categories, only: [:index, :show, :create, :update, :destroy]

    # Resources for files management
    resources :files, only: [:index, :create, :destroy]

    # Resources for orders management
    resources :orders do
      collection do
        get :graveyard_orders
      end
      member do
        patch :pick_up_order
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
