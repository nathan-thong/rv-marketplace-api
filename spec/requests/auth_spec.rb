require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /register" do
    it "registers a user and returns token" do
      email = unique_email("jane")

      post "/register", params: {
        user: {
          name: "Jane",
          email: email,
          password: "password",
          password_confirmation: "password"
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body.dig("user", "email")).to eq(email)
    end

    it "rejects duplicate email" do
      email = unique_email("jane")
      User.create!(name: "Jane", email: email, password: "password", password_confirmation: "password")

      post "/register", params: {
        user: {
          name: "Another Jane",
          email: email,
          password: "password",
          password_confirmation: "password"
        }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "downcases the email before saving" do
      email = "Owner#{unique_email("case")}"
      post "/register", params: {
        user: {
          name: "Owner",
          email: email,
          password: "password123",
          password_confirmation: "password123"
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)

      expect(body["user"]["email"]).to eq(email.downcase)
      expect(User.last.email).to eq(email.downcase)
    end
  end

  describe "POST /login" do
    let(:email) { unique_email("jane") }
    let!(:user) { User.create!(name: "Jane", email: email, password: "password", password_confirmation: "password") }

    it "logs in with valid credentials" do
      post "/login", params: { user: { email: user.email, password: "password" } }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body.dig("user", "id")).to eq(user.id)
    end

    it "rejects invalid credentials" do
      post "/login", params: { user: { email: user.email, password: "wrong" } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts email case-insensitively" do
      login_email = unique_email("owner")

      User.create!(
        name: "Owner",
        email: login_email,
        password: "password123",
        password_confirmation: "password123"
      )

      post "/login", params: {
        user: {
          email: login_email.upcase,
          password: "password123"
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["token"]).to be_present
      expect(body["user"]["email"]).to eq(login_email)
    end

    it "rejects a bad password" do
      login_email = unique_email("ownerbad")

      User.create!(
        name: "Owner",
        email: login_email,
        password: "password123",
        password_confirmation: "password123"
      )

      post "/login", params: {
        user: {
          email: login_email.upcase,
          password: "wrong-password"
        }
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
