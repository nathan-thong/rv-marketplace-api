require "swagger_helper"

RSpec.describe "Auth API", type: :request do
  path "/register" do
    post "Register a new user" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              name: { type: :string, example: "Jane" },
              email: { type: :string, example: "jane@example.com" },
              password: { type: :string, example: "password" },
              password_confirmation: { type: :string, example: "password" }
            },
            required: %w[name email password password_confirmation]
          }
        },
        required: [ "user" ]
      }

      response "201", "user registered" do
        let(:payload) do
          {
            user: {
              name: "Jane",
              email: unique_email("register"),
              password: "password",
              password_confirmation: "password"
            }
          }
        end

        run_test!
      end

      response "422", "invalid input" do
        let(:payload) do
          {
            user: {
              name: "",
              email: "bad-email",
              password: "pass",
              password_confirmation: "nope"
            }
          }
        end

        run_test!
      end
    end
  end

  path "/login" do
    post "Login and receive JWT token" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: "jane@example.com" },
              password: { type: :string, example: "password" }
            },
            required: %w[email password]
          }
        },
        required: [ "user" ]
      }

      response "200", "login successful" do
        let!(:user) do
          User.create!(
            name: "Jane",
            email: unique_email("login"),
            password: "password",
            password_confirmation: "password"
          )
        end

        let(:payload) do
          { user: { email: user.email, password: "password" } }
        end

        run_test!
      end

      response "401", "invalid credentials" do
        let(:payload) do
          { user: { email: "missing@example.com", password: "wrong" } }
        end

        run_test!
      end
    end
  end
end
