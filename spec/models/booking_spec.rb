require "rails_helper"

RSpec.describe Booking, type: :model do
  let(:owner) { User.create!(name: "Owner", email: unique_email("owner-bm"), password: "password", password_confirmation: "password") }
  let(:hirer) { User.create!(name: "Hirer", email: unique_email("hirer-bm"), password: "password", password_confirmation: "password") }
  let(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "is valid with valid dates and status" do
    booking = described_class.new(start_date: Date.today + 1, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).to be_valid
  end

  it "requires start_date" do
    booking = described_class.new(end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).not_to be_valid
  end

  it "requires end_date" do
    booking = described_class.new(start_date: Date.today + 1, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).not_to be_valid
  end

  it "rejects invalid status" do
    booking = described_class.new(start_date: Date.today + 1, end_date: Date.today + 2, status: "maybe", user: hirer, rv_listing: listing)
    expect(booking).not_to be_valid
  end

  it "rejects end_date equal to start_date" do
    booking = described_class.new(start_date: Date.today + 2, end_date: Date.today + 2, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).not_to be_valid
  end

  it "rejects end_date before start_date" do
    booking = described_class.new(start_date: Date.today + 2, end_date: Date.today + 1, status: "pending", user: hirer, rv_listing: listing)
    expect(booking).not_to be_valid
  end

  it "belongs to a user" do
    expect(described_class.reflect_on_association(:user).macro)
      .to eq(:belongs_to)
  end

  it "belongs to a listing" do
    expect(described_class.reflect_on_association(:rv_listing).macro)
      .to eq(:belongs_to)
  end
end
