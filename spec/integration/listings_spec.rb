require "swagger_helper"

RSpec.describe "Listings API", type: :request do
  path "/listings" do
    get "List all RV listings" do
      tags "Listings"
      produces "application/json"

      response "200", "listings returned" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-list"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

        run_test!
      end
    end

    post "Create a new RV listing" do
      tags "Listings"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          rv_listing: {
            type: :object,
            properties: {
              title: { type: :string, example: "Cozy Camper" },
              description: { type: :string, example: "Great for weekends" },
              location: { type: :string, example: "Melbourne" },
              price_per_day: { type: :number, example: 120 }
            },
            required: %w[title description location price_per_day]
          }
        },
        required: [ "rv_listing" ]
      }

      response "201", "listing created" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-create"), password: "password", password_confirmation: "password") }
        let(:Authorization) { auth_headers(owner)["Authorization"] }
        let(:payload) do
          {
            rv_listing: {
              title: "Cozy Camper",
              description: "Great for weekends",
              location: "Melbourne",
              price_per_day: 120
            }
          }
        end

        run_test!
      end

      response "401", "unauthorized" do
        let(:Authorization) { nil }
        let(:payload) do
          {
            rv_listing: {
              title: "Cozy Camper",
              description: "Great for weekends",
              location: "Melbourne",
              price_per_day: 120
            }
          }
        end

        run_test!
      end
    end
  end

  path "/listings/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Show a single RV listing" do
      tags "Listings"
      produces "application/json"

      response "200", "listing found" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-show"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let(:id) { listing.id }

        run_test!
      end
    end

    patch "Update an RV listing (owner only)" do
      tags "Listings"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          rv_listing: {
            type: :object,
            properties: {
              title: { type: :string, example: "Updated RV Title" }
            }
          }
        },
        required: [ "rv_listing" ]
      }

    put "Replace an RV listing (owner only)" do
      tags "Listings"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          rv_listing: {
            type: :object,
            properties: {
              title: { type: :string, example: "Updated RV Title" }
            }
          }
        },
        required: [ "rv_listing" ]
      }

      response "200", "updated by owner" do
        let!(:owner) do
          User.create!(
            name: "Owner",
            email: unique_email("owner-put"),
            password: "password",
            password_confirmation: "password"
          )
        end

        let!(:listing) do
          RvListing.create!(
            title: "RV One",
            description: "Nice",
            location: "Sydney",
            price_per_day: 100,
            user: owner
          )
        end

        let(:id) { listing.id }
        let(:Authorization) { auth_headers(owner)["Authorization"] }
        let(:payload) do
          {
            rv_listing: {
              title: "Updated RV Title"
            }
          }
        end

        run_test!
      end

      response "403", "forbidden for non-owner" do
        let!(:owner) do
          User.create!(
            name: "Owner",
            email: unique_email("owner-put-forbid"),
            password: "password",
            password_confirmation: "password"
          )
        end

        let!(:other_user) do
          User.create!(
            name: "Other",
            email: unique_email("other-put-forbid"),
            password: "password",
            password_confirmation: "password"
          )
        end

        let!(:listing) do
          RvListing.create!(
            title: "RV One",
            description: "Nice",
            location: "Sydney",
            price_per_day: 100,
            user: owner
          )
        end

        let(:id) { listing.id }
        let(:Authorization) { auth_headers(other_user)["Authorization"] }
        let(:payload) do
          {
            rv_listing: {
              title: "Hacked"
            }
          }
        end

        run_test!
      end
    end

      response "200", "updated by owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-update"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let(:id) { listing.id }
        let(:Authorization) { auth_headers(owner)["Authorization"] }
        let(:payload) { { rv_listing: { title: "Updated RV Title" } } }

        run_test!
      end

      response "403", "forbidden for non-owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-forbid"), password: "password", password_confirmation: "password") }
        let!(:other_user) { User.create!(name: "Other", email: unique_email("other-forbid"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let(:id) { listing.id }
        let(:Authorization) { auth_headers(other_user)["Authorization"] }
        let(:payload) { { rv_listing: { title: "Hacked" } } }

        run_test!
      end
    end

    delete "Delete an RV listing (owner only)" do
      tags "Listings"
      produces "application/json"
      security [ bearerAuth: [] ]


      response "200", "deleted by owner" do
        let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-delete"), password: "password", password_confirmation: "password") }
        let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
        let(:id) { listing.id }
        let(:Authorization) { auth_headers(owner)["Authorization"] }

        run_test!
      end
    end
  end
end
