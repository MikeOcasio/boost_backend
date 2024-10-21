Rails.application.routes.draw do
  root to: 'application#health_check'

  #### User Authentication Routes ####
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    unlocks: 'users/unlocks'
  }

  namespace :users do
    resources :members, path: 'member-data', only: [:index, :create, :show, :update, :destroy] do
      member do
        get :platforms
        post :add_platform
        delete :remove_platform
        post :lock, to: 'members#lock_user'
        post :unlock, to: 'members#unlock_user'
      end

      collection do
        get :signed_in_user
        get :skillmasters
      end

      member do
        get 'skillmasters/:id', to: 'members#show_skillmaster', as: 'show_skillmaster'
        delete 'ban', to: 'members#destroy_and_ban', as: 'destroy_and_ban'
      end
    end

    resource :two_factor_authentication, only: [:show], controller: 'two_factor_authentication' do
      post 'verify', to: 'two_factor_authentication#verify'
    end

    # Adding the skillmaster applications routes
    resources :skillmaster_applications, only: [:show]
  end

  namespace :orders do
    resources :orders, path: 'info', only: [:index, :show, :create, :update, :destroy] do
      member do
        post 'pick_up_order'  # POST /orders/:id/pick_up_order
        get 'download_invoice'  # GET /orders/:id/download_invoice
      end

      collection do
        get 'graveyard_orders'  # GET /orders/graveyard_orders
      end
    end
  end

  delete 'users/sign_out', to: 'users/sessions#destroy'

  namespace :api do
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
    resources :prod_attr_cats do
      member do
        get :products
      end
    end
    # Resources for categories with limited actions
    resources :categories, only: [:index, :show, :create, :update, :destroy]

    # Resources for files management
    resources :files, only: [:index, :create, :destroy]

    resources :skillmasters, only: [:index, :show]

    resources :platform_credentials, only: [:show, :create, :update, :destroy]
  end

  # CSRF token route for frontend usage
  get '/csrf_token', to: 'application#csrf_token'

  # Routes for secure data management
  get '/generate_symmetric_key', to: 'secure_data#generate_symmetric_key'
  get '/generate_asymmetric_key_pair', to: 'secure_data#generate_asymmetric_key_pair'
  post '/encrypt_data', to: 'secure_data#encrypt_data'
  post '/encrypt_symmetric_key', to: 'secure_data#encrypt_symmetric_key'
end
