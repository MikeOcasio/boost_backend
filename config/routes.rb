Rails.application.routes.draw do
  root to: 'application#health_check'

  #### User Authentication Routes ####
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    unlocks: 'users/unlocks',
    passwords: 'users/passwords',
    two_factor_authentication: 'users/two_factor_authentication'
  }

  # Custom route for updating 2FA method
  post 'users/two_factor_authentication/update_method', to: 'users/two_factor_authentication#update_method'

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
      post 'send_otp_email', to: 'two_factor_authentication#send_otp_email' # New route for sending OTP email
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
        get 'by_category/:category_id', to: 'products#by_category'
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
      collection do
        get 'by_code', to: 'promotions#show_by_code'
      end
    end

    resources :skillmasters, only: %i[index show]

    resources :platform_credentials, only: %i[show create update destroy]

    resources :payments, only: [] do
      post 'create_checkout_session', on: :collection
    end

    resource :app_status, only: %i[show update], controller: 'app_status'

    resources :chats, only: %i[index show create] do
      resources :messages, only: %i[create]
      member do
        post :archive
      end
    end

    resources :broadcast_messages, only: %i[index create]

    resources :user_rewards, only: [:index] do
      member do
        post :claim
      end
    end

    resources :reviews, only: %i[index create show destroy] do
      collection do
        get 'product/:product_id', to: 'reviews#index', defaults: { type: 'product' }
        get 'skillmaster/:skillmaster_id', to: 'reviews#index', defaults: { type: 'skillmaster' }
        get 'website', to: 'reviews#index', defaults: { type: 'website' }
        get 'orders', to: 'reviews#index', defaults: { type: 'order' }
      end
    end
  end
end
