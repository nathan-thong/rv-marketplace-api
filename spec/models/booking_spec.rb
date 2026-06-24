require "rails_helper"

RSpec.describe Booking, type: :model do
  let(:owner) { User.create!(name: "Owner", email: "owner-bm@example.com", password: "password", password_confirmation: "password") }
  let(:hirer) { User.create!(name: "Hirer", email: "hirer-bm@example.com", password: "password", password_confirmation: "password") }
  let(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "is valid with valid dates and status" do
    booking = described_class.new(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).to be_valid
  end

  it "rejects end_date before or equal start_date" do
    booking = described_class.new(start_date: Date.today + 2, end_date: Date.today + 1, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).not_to be_valid
  end
end
