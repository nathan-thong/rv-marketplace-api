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

  describe "overlap validation" do
    let!(:existing) do
      Booking.create!(start_date: Date.today + 10, end_date: Date.today + 15, status: "pending", user: hirer, rv_listing: listing)
    end

    it "rejects an overlapping pending booking" do
      booking = described_class.new(start_date: Date.today + 12, end_date: Date.today + 17, status: "pending", user: hirer, rv_listing: listing)
      expect(booking).not_to be_valid
      expect(booking.errors[:base]).to include("These dates are not available for this listing")
    end

    it "rejects an overlapping booking when the existing one is confirmed" do
      existing.update!(status: "confirmed")
      booking = described_class.new(start_date: Date.today + 12, end_date: Date.today + 17, status: "pending", user: hirer, rv_listing: listing)
      expect(booking).not_to be_valid
    end

    it "rejects when the new booking itself is confirmed and overlaps" do
      booking = described_class.new(start_date: Date.today + 12, end_date: Date.today + 17, status: "confirmed", user: hirer, rv_listing: listing)
      expect(booking).not_to be_valid
    end

    it "allows same-day turnover (checkout day == next checkin day)" do
      booking = described_class.new(start_date: Date.today + 15, end_date: Date.today + 18, status: "pending", user: hirer, rv_listing: listing)
      expect(booking).to be_valid
    end

    it "allows overlapping dates against a rejected booking" do
      existing.update!(status: "rejected")
      booking = described_class.new(start_date: Date.today + 12, end_date: Date.today + 17, status: "pending", user: hirer, rv_listing: listing)
      expect(booking).to be_valid
    end

    it "allows the same overlapping dates on a different listing" do
      other_listing = RvListing.create!(title: "RV Two", description: "Nice", location: "Perth", price_per_day: 80, user: owner)
      booking = described_class.new(start_date: Date.today + 12, end_date: Date.today + 17, status: "pending", user: hirer, rv_listing: other_listing)
      expect(booking).to be_valid
    end

    it "is blocked at the database level even if validation is bypassed" do
      # Uses a date range disjoint from `existing` (day 10-15) so only the
      # two bookings created here are exercising the DB constraint.
      booking = described_class.new(start_date: Date.today + 30, end_date: Date.today + 33, status: "pending", user: hirer, rv_listing: listing)
      booking.save(validate: false)

      expect { described_class.new(start_date: Date.today + 31, end_date: Date.today + 32, status: "pending", user: hirer, rv_listing: listing).save(validate: false) }
        .to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
