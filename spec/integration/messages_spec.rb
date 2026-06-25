require "swagger_helper"

RSpec.describe "Messages API", type: :request do
  path "/listings/{listing_id}/messages" do
    parameter name: :listing_id, in: :path, schema: { type: :integer }

    get "List messages for a listing (authenticated users)" do
      tags "Messages"
      produces "application/json"
      security [ bearerAuth: [] ]

      response "200", "authenticated user can list messages" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg-index"), password: "password", password_confirmation: "password") }
        let!(:user) { User.create!(name: "User", email: unique_email("user-msg-index"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(user)["Authorization"] }

        run_test!
      end

      response "401", "unauthenticated request rejected" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg-unauth"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

        let(:listing_id) { listing.id }
        let(:Authorization) { nil }

        run_test!
      end
    end

    post "Create a message for a listing (authenticated users)" do
      tags "Messages"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          message: {
            type: :object,
            properties: {
              content: { type: :string, example: "Is this RV available next weekend?" }
            },
            required: [ "content" ]
          }
        },
        required: [ "message" ]
      }

      response "201", "authenticated user can create message" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg-create"), password: "password", password_confirmation: "password") }
        let!(:user) { User.create!(name: "User", email: unique_email("user-msg-create"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(user)["Authorization"] }
        let(:payload) { { message: { content: "Is this RV available next weekend?" } } }

        run_test!
      end
    end
  end
end
