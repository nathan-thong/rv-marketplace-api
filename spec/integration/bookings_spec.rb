require "swagger_helper"

RSpec.describe "Bookings API", type: :request do
  path "/listings/{listing_id}/bookings" do
    post "Create a booking request for a listing" do
      tags "Bookings"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :listing_id, in: :path, schema: { type: :integer }
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          booking: {
            type: :object,
            properties: {
              start_date: { type: :string, format: :date, example: "2026-07-01" },
              end_date: { type: :string, format: :date, example: "2026-07-05" }
            },
            required: %w[start_date end_date]
          }
        },
        required: [ "booking" ]
      }

      response "201", "booking created by non-owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-book"), password: "password", password_confirmation: "password") }
        let!(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-book"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(hirer)["Authorization"] }
        let(:payload) { { booking: { start_date: Date.today + 1, end_date: Date.today + 2 } } }

        run_test!
      end

      response "403", "owner cannot book own listing" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-own-book"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

        let(:listing_id) { listing.id }
        let(:Authorization) { auth_headers(owner)["Authorization"] }
        let(:payload) { { booking: { start_date: Date.today + 1, end_date: Date.today + 2 } } }

        run_test!
      end
    end
  end

  path "/bookings" do
    get "List bookings for authenticated user (as hirer or owner)" do
      tags "Bookings"
      produces "application/json"
      security [ bearerAuth: [] ]


      response "200", "bookings returned" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-index"), password: "password", password_confirmation: "password") }
        let!(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-index"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing) }

        let(:Authorization) { auth_headers(owner)["Authorization"] }

        run_test!
      end
    end
  end

  path "/bookings/{id}/confirm" do
    patch "Confirm a booking (listing owner only)" do
      tags "Bookings"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :id, in: :path, schema: { type: :integer }

      response "200", "confirmed by owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-confirm"), password: "password", password_confirmation: "password") }
        let!(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-confirm"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing) }

        let(:id) { booking.id }
        let(:Authorization) { auth_headers(owner)["Authorization"] }

        run_test!
      end

      response "403", "forbidden for non-owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-confirm-forbid"), password: "password", password_confirmation: "password") }
        let!(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-confirm-forbid"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing) }

        let(:id) { booking.id }
        let(:Authorization) { auth_headers(hirer)["Authorization"] }

        run_test!
      end
    end
  end

  path "/bookings/{id}/reject" do
    patch "Reject a booking (listing owner only)" do
      tags "Bookings"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :id, in: :path, schema: { type: :integer }

      response "200", "rejected by owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-reject"), password: "password", password_confirmation: "password") }
        let!(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-reject"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing) }

        let(:id) { booking.id }
        let(:Authorization) { auth_headers(owner)["Authorization"] }

        run_test!
      end
    end
  end
end
