require "rails_helper"

RSpec.describe "Listings", type: :request do
  let!(:owner) { User.create!(name: "Owner", email: "owner@example.com", password: "password", password_confirmation: "password") }
  let!(:other_user) { User.create!(name: "Other", email: "other@example.com", password: "password", password_confirmation: "password") }
  let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "lists all listings publicly" do
    get "/listings"
    expect(response).to have_http_status(:ok)
  end

  it "shows a single listing publicly" do
    get "/listings/#{listing.id}"
    expect(response).to have_http_status(:ok)
  end

  it "creates listing for authenticated user" do
    post "/listings",
      params: { rv_listing: { title: "New RV", description: "Great", location: "Melbourne", price_per_day: 120 } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:created)
  end

  it "blocks unauthenticated create" do
    post "/listings",
      params: { rv_listing: { title: "New RV", description: "Great", location: "Melbourne", price_per_day: 120 } },
      as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "allows owner update" do
    patch "/listings/#{listing.id}",
      params: { rv_listing: { title: "Updated" } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:ok)
  end

  it "blocks non-owner update" do
    patch "/listings/#{listing.id}",
      params: { rv_listing: { title: "Hacked" } },
      headers: auth_headers(other_user),
      as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
