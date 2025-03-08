module Api
  class AppStatusController < ApplicationController
    def show
      app_status = AppStatus.current
      render json: {
        status: app_status.status,
        message: app_status.message,
        maintenance: app_status.maintenance?,
        updated_at: app_status.updated_at
      }
    end

    def update
      return head :forbidden unless current_user&.admin?

      app_status = AppStatus.current
      if app_status.update(app_status_params)
        render json: {
          status: app_status.status,
          message: app_status.message,
          maintenance: app_status.maintenance?,
          updated_at: app_status.updated_at
        }
      else
        render json: { errors: app_status.errors }, status: :unprocessable_entity
      end
    end

    private

    def app_status_params
      params.require(:app_status).permit(:status, :message)
    end
  end
end
