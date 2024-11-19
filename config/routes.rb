Rails.application.routes.draw do
  root to: 'application#health_check'

  #### User Authentication Routes ####
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    unlocks: 'users/unlocks',
    passwords: 'users/passwords'
  }

  namespace :users do
    resources :members, path: 'member-data', only: %i[index create show update destroy] do
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
        patch 'update_password', to: 'members#update_password'
        get 'user_exists', to: 'members#user_exists'
      end

      member do
        get 'skillmasters/:id', to: 'members#show_skillmaster', as: 'show_skillmaster'
        delete 'ban', to: 'members#destroy_and_ban', as: 'destroy_and_ban'
      end
    end

    # Change the two_factor_authentication route to 2fa
    resource :two_factor_authentication, only: [:show], controller: 'two_factor_authentication', path: '2fa' do
      post 'verify', to: 'two_factor_authentication#verify'
    end

    # Adding the skillmaster applications routes
    resources :skillmaster_applications

    resources :banned_emails, only: [:index]
  end

  namespace :orders do
    resources :orders, path: 'info', only: %i[index show create update destroy] do
      member do
        post 'pick_up_order' # POST /orders/:id/pick_up_order
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

      # Nested routes for sub-platforms under platforms
      resources :sub_platforms, only: %i[index create show update destroy]
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
        get :products # Get products for a specific category
      end
    end

    # Resources for product attribute categories
    resources :prod_attr_cats do
      member do
        get :products
      end
    end
    # Resources for categories with limited actions
    resources :categories, only: %i[index show create update destroy]

    resources :promotions do
      member do
        post :apply_to_order
      end
    end

    # Resources for files management
    resources :files, only: %i[index create destroy]

    resources :skillmasters, only: %i[index show]

    resources :platform_credentials, only: %i[show create update destroy]

    resources :payments, only: [] do
      post 'create_checkout_session', on: :collection
    end
  end
end
