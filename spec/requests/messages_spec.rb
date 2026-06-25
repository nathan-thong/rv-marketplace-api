require "rails_helper"

RSpec.describe "Messages", type: :request do
  let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-m"), password: "password", password_confirmation: "password") }
  let!(:user) { User.create!(name: "User", email: unique_email("user-m"), password: "password", password_confirmation: "password") }
  let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "allows any authenticated user to list messages" do
    get "/listings/#{listing.id}/messages", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
  end

  it "allows any authenticated user to create a message" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Is this available?" } },
      headers: auth_headers(user),
      as: :json

    expect(response).to have_http_status(:created)
  end

  it "blocks unauthenticated users from listing messages" do
    get "/listings/#{listing.id}/messages"
    expect(response).to have_http_status(:unauthorized)
  end

  it "blocks unauthenticated users from creating messages" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Is this available?" } },
      as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
