require "rails_helper"

RSpec.describe "Listings", type: :request do
  let!(:owner) { User.create!(name: "Owner", email: unique_email("owner"), password: "password", password_confirmation: "password") }
  let!(:other_user) { User.create!(name: "Other", email: unique_email("other"), password: "password", password_confirmation: "password") }
  let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "lists all listings publicly" do
    get "/listings"
    expect(response).to have_http_status(:ok)
  end

  it "shows a single listing publicly" do
    get "/listings/#{listing.id}"
    expect(response).to have_http_status(:ok)
  end

  it "returns not found for missing listing" do
    get "/listings/999999"
    expect(response).to have_http_status(:not_found)
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

  it "rejects invalid create" do
    post "/listings",
      params: { rv_listing: { title: "", description: "", location: "", price_per_day: 0 } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "allows owner update" do
    patch "/listings/#{listing.id}",
      params: { rv_listing: { title: "Updated" } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(listing.reload.title).to eq("Updated")
  end

  it "blocks non-owner update" do
    patch "/listings/#{listing.id}",
      params: { rv_listing: { title: "Hacked" } },
      headers: auth_headers(other_user),
      as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "blocks unauthenticated update" do
    patch "/listings/#{listing.id}",
      params: { rv_listing: { title: "Nope" } },
      as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects invalid update" do
    patch "/listings/#{listing.id}",
      params: { rv_listing: { price_per_day: 0 } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "allows owner delete" do
    delete "/listings/#{listing.id}",
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(RvListing.exists?(listing.id)).to be(false)
  end

  it "blocks non-owner delete" do
    delete "/listings/#{listing.id}",
      headers: auth_headers(other_user),
      as: :json

    expect(response).to have_http_status(:forbidden)
    expect(RvListing.exists?(listing.id)).to be(true)
  end

  it "blocks unauthenticated delete" do
    delete "/listings/#{listing.id}", as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(RvListing.exists?(listing.id)).to be(true)
  end
end
