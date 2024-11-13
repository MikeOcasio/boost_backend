# app/controllers/users/passwords_controller.rb
module Users
  class PasswordsController < Devise::PasswordsController
    # No custom behavior; this inherits from Devise::PasswordsController

    def update
      super do |resource|
        if resource.errors.empty?
          redirect_to after_resetting_password_path_for(resource), allow_other_host: true
          return # Prevent further execution
        end
      end
    end

    protected

    # Redirect to the frontend URL after password change
    def after_resetting_password_path_for(_)
      Rails.env.development? ? 'http://localhost:3001/login' : 'https://www.ravenboost.com/login'
    end
  end
end
