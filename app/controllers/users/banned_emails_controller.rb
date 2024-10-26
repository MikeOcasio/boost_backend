# app/controllers/users/banned_emails_controller.rb
module Users
  class BannedEmailsController < ApplicationController
    before_action :authenticate_user!, :authorize_admin

    def index
      @banned_emails = BannedEmail.all
      render json: @banned_emails, status: :ok
    end

    private

    def authorize_admin
      return if current_user.role == 'admin' || current_user.role == 'dev'

      render json: { error: 'You are not authorized to perform this action.' }, status: :forbidden
    end
  end
end
