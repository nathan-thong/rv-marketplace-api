module AuthHelpers
  def jwt_for(user)
    secret = ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, secret, "HS256")
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{jwt_for(user)}" }
  end
end
