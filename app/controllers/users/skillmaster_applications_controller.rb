class Users::SkillmasterApplicationsController < ApplicationController

  before_action :set_application, only: [:show]

    # GET /users/skillmaster_applications/:id
    def show
      render json: @application
    end

    private

    def set_application
      @application = SkillmasterApplication.find(params[:id])
      # Optionally, you might want to check if the current user is authorized to view this application
      # For example:
      # render json: { error: 'Not authorized' }, status: :forbidden unless @application.user_id == current_user.id

      
end
