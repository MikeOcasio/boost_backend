# config/routes.rb

Rails.application.routes.draw do
  # Define a root route that returns a simple response or redirect
  root to: 'application#health_check'

  namespace :api do
    devise_for :users, skip: [:sessions, :registrations]
    get '/users/skillmasters', to: 'users#skillmasters'
    post '/login', to: 'users#login'
    get '/current_user', to: 'users#show_current_user'
    get '/csrf_token', to: 'application#csrf_token'

    resources :categories, only: [:index, :show, :create, :update, :destroy]
    resources :files, only: [:index, :create, :destroy]
    resources :users
    resources :orders
    resources :products

    get '/graveyard_orders', to: 'orders#graveyard_orders'
    patch '/orders/:id/pick_up_order', to: 'orders#pick_up_order'
  end

  get '/generate_symmetric_key', to: 'secure_data#generate_symmetric_key'
  get '/generate_asymmetric_key_pair', to: 'secure_data#generate_asymmetric_key_pair'
  post '/encrypt_data', to: 'secure_data#encrypt_data'
  post '/encrypt_symmetric_key', to: 'secure_data#encrypt_symmetric_key'
end
