# app/controllers/users/passwords_controller.rb
module Users
  class PasswordsController < Devise::PasswordsController
    # No custom behavior; this inherits from Devise::PasswordsController

    protected

    # Redirect to the frontend URL after password change
    def after_resetting_password_path_for(_)
      Rails.env.development? ? 'http://127.0.0.1:3001/login' : 'https://www.ravenboost.com/login'
    end
  end
end
