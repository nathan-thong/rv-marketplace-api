require "rails_helper"

RSpec.describe RvListing, type: :model do
  let(:user) { User.create!(name: "Owner", email: "owner-l@example.com", password: "password", password_confirmation: "password") }

  it "is valid with required attributes" do
    listing = described_class.new(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: user)
    expect(listing).to be_valid
  end

  it "requires title" do
    listing = described_class.new(description: "Nice", location: "Sydney", price_per_day: 100, user: user)
    expect(listing).not_to be_valid
  end
end
