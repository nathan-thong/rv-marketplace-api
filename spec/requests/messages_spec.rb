require "rails_helper"

RSpec.describe "Messages", type: :request do
  let!(:owner) { User.create!(name: "Owner", email: "owner-m@example.com", password: "password", password_confirmation: "password") }
  let!(:participant) { User.create!(name: "Participant", email: "participant-m@example.com", password: "password", password_confirmation: "password") }
  let!(:stranger) { User.create!(name: "Stranger", email: "stranger-m@example.com", password: "password", password_confirmation: "password") }
  let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
  let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: participant, rv_listing: listing) }

  it "allows participant to list messages" do
    get "/listings/#{listing.id}/messages", headers: auth_headers(participant)
    expect(response).to have_http_status(:ok)
  end

  it "allows participant to create message" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Is this available?" } },
      headers: auth_headers(participant),
      as: :json

    expect(response).to have_http_status(:created)
  end

  it "blocks stranger from listing messages" do
    get "/listings/#{listing.id}/messages", headers: auth_headers(stranger)
    expect(response).to have_http_status(:forbidden)
  end
end
