require "swagger_helper"

RSpec.describe "Messages API", type: :request do
  path "/listings/{listing_id}/messages" do
    parameter name: :listing_id, in: :path, schema: { type: :integer }

    get "List messages for a listing (participants only)" do
      tags "Messages"
      produces "application/json"
      security [ bearerAuth: [] ]

      response "200", "participant can list messages" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg-index"), password: "password", password_confirmation: "password") }
        let!(:participant) { User.create!(name: "Participant", email: unique_email("participant-msg-index"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: participant, rv_listing: listing) }
        let!(:message) { Message.create!(content: "Hi, available?", user: participant, rv_listing: listing) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(participant)["Authorization"] }

        run_test!
      end

      response "403", "stranger forbidden" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg-forbid"), password: "password", password_confirmation: "password") }
        let!(:participant) { User.create!(name: "Participant", email: unique_email("participant-msg-forbid"), password: "password", password_confirmation: "password") }
        let!(:stranger) { User.create!(name: "Stranger", email: unique_email("stranger-msg-forbid"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: participant, rv_listing: listing) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(stranger)["Authorization"] }

        run_test!
      end
    end

    post "Create a message for a listing (participants only)" do
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

      response "201", "participant can create message" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg-create"), password: "password", password_confirmation: "password") }
        let!(:participant) { User.create!(name: "Participant", email: unique_email("participant-msg-create"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: participant, rv_listing: listing) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(participant)["Authorization"] }
        let(:payload) { { message: { content: "Is this RV available next weekend?" } } }

        run_test!
      end
    end
  end
end
