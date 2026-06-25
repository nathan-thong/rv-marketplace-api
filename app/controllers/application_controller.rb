class ApplicationController < ActionController::API
  private

  def jwt_secret
    ENV.fetch("JWT_SECRET")
  end
end
