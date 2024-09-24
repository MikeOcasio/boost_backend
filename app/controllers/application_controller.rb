class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers
  def health_check
    render plain: "OK", status: :ok
  end
end
