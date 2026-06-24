require "rails_helper"

RSpec.describe "Bookings", type: :request do
  let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-b"), password: "password", password_confirmation: "password") }
  let!(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-b"), password: "password", password_confirmation: "password") }
  let!(:other) { User.create!(name: "Other", email: unique_email("other-b"), password: "password", password_confirmation: "password") }
  let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }
  let!(:booking) { Booking.create!(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing) }

  it "creates booking for non-owner" do
    post "/listings/#{listing.id}/bookings",
      params: { booking: { start_date: Date.today + 5, end_date: Date.today + 6 } },
      headers: auth_headers(hirer),
      as: :json

    expect(response).to have_http_status(:created)
  end

  it "blocks owner from booking own listing" do
    post "/listings/#{listing.id}/bookings",
      params: { booking: { start_date: Date.today + 5, end_date: Date.today + 6 } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "returns bookings for authenticated user" do
    get "/bookings", headers: auth_headers(owner)
    expect(response).to have_http_status(:ok)
  end

  it "allows owner to confirm" do
    patch "/bookings/#{booking.id}/confirm", headers: auth_headers(owner)
    expect(response).to have_http_status(:ok)
    expect(booking.reload.status).to eq("confirmed")
  end

  it "blocks non-owner from confirming" do
    patch "/bookings/#{booking.id}/confirm", headers: auth_headers(other)
    expect(response).to have_http_status(:forbidden)
  end
end
