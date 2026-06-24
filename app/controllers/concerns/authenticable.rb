module Authenticable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    token = extract_token
    payload = decode_token(token)
    @current_user = User.find(payload["user_id"])
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def extract_token
    request.headers.fetch("Authorization", "").sub(/^Bearer /, "")
  end

  def decode_token(token)
    JWT.decode(token, jwt_secret, true, algorithm: "HS256")[0]
  end

  def current_user
    @current_user
  end
end
