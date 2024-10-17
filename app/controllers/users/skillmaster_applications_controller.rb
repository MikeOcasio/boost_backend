class Users::SkillmasterApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show]

  # GET /users/skillmaster_applications/:id
  def show
    render json: @application
  end

  def index
    if current_user.role == "admin" || current_user.role == "dev"
      @applications = SkillmasterApplication.all
      render json: @applications
    elsif current_user.id == params[:id]
      @applications = SkillmasterApplication.where(user_id: current_user.id)
      render json: @applications
    else
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
  end

  #! TODO: Implement the create action
  def create
    @application = SkillmasterApplication.new(application_params)
    @application.user_id = current_user.id

    if @application.save
      render json: @application, status: :created
    else
      render json: @application.errors, status: :unprocessable_entity
    end
  end

  def update
    if current_user.role == "admin" || current_user.role == "dev"
      # Handle the update
    elsif current_user.id == params[:id]
      # Handle the update
    else
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
  end

  private

  def set_application
    @application = SkillmasterApplication.find(params[:id])
    # Optionally, you might want to check if the current user is authorized to view this application
    # For example:
    # render json: { error: 'Not authorized' }, status: :forbidden unless @application.user_id == current_user.id
  end

  def application_params
    params.require(:skillmaster_application).permit(:your_permitted_fields_here)
  end
end
