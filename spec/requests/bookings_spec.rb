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

  it "blocks unauthenticated booking create" do
    post "/listings/#{listing.id}/bookings",
      params: { booking: { start_date: Date.today + 5, end_date: Date.today + 6 } },
      as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "blocks owner from booking own listing" do
    post "/listings/#{listing.id}/bookings",
      params: { booking: { start_date: Date.today + 5, end_date: Date.today + 6 } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects invalid booking dates" do
    post "/listings/#{listing.id}/bookings",
      params: { booking: { start_date: Date.today + 6, end_date: Date.today + 5 } },
      headers: auth_headers(hirer),
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns bookings for owner" do
    get "/bookings", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.map { |b| b["id"] }).to include(booking.id)
  end

  it "returns bookings for hirer" do
    get "/bookings", headers: auth_headers(hirer)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.map { |b| b["id"] }).to include(booking.id)
  end

  it "blocks unauthenticated bookings index" do
    get "/bookings"
    expect(response).to have_http_status(:unauthorized)
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

  it "blocks unauthenticated confirm" do
    patch "/bookings/#{booking.id}/confirm"

    expect(response).to have_http_status(:unauthorized)
  end

  it "allows owner to reject" do
    patch "/bookings/#{booking.id}/reject", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    expect(booking.reload.status).to eq("rejected")
  end

  it "blocks non-owner from rejecting" do
    patch "/bookings/#{booking.id}/reject", headers: auth_headers(other)

    expect(response).to have_http_status(:forbidden)
  end

  it "blocks unauthenticated reject" do
    patch "/bookings/#{booking.id}/reject"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns not found for missing booking on confirm" do
    patch "/bookings/999999/confirm", headers: auth_headers(owner)

    expect(response).to have_http_status(:not_found)
  end
end
