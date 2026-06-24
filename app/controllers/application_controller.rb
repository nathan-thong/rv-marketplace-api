class ApplicationController < ActionController::API
  private

  def jwt_secret
    ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
  end
end
