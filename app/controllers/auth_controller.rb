class AuthController < ApplicationController
  def register
    user = User.new(register_params)
    if user.save
      token = generate_token(user.id)
      render json: {
        user: user.slice(:id, :name, :email, :created_at, :updated_at),
        token: token
      }, status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: login_params[:email])
    if user&.authenticate(login_params[:password])
      token = generate_token(user.id)
      render json: {
        user: user.slice(:id, :name, :email, :created_at, :updated_at),
        token: token
      }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  private

  def register_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def login_params
    params.require(:user).permit(:email, :password)
  end

  def generate_token(user_id)
    JWT.encode({ user_id: user_id, exp: 24.hours.from_now.to_i }, jwt_secret, "HS256")
  end
end
