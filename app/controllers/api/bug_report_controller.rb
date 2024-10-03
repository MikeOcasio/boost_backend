module Api
  class BugReportController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_developer!, only: [:index, :show, :update, :destroy]
    before_action :set_bug_report, only: [:show, :update, :destroy]


    def index
      @bug_reports = BugReport.all
      render json: @bug_reports
    end

    def show
      render json: @bug_report
    end

    def create
      @bug_report = current_user.bug_reports.build(bug_report_params)
      if @bug_report.save
        render json: @bug_report, status: :created
      else
        render json: @bug_report.errors, status: :unprocessable_entity
      end
    end

    def update
      authorize_developer!
      if @bug_report.update(bug_report_params)
        render json: @bug_report, status: :ok
      else
        render json: @bug_report.errors, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_developer!
      @bug_report.destroy
      head :no_content
    end

    private

    def set_bug_report
      @bug_report = BugReport.find(params[:id])
    end

    def bug_report_params
      params.require(:bug_report).permit(:title, :description)
    end

    def authorize_developer!
      unless current_user.role == 'dev'
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
