require "rails_helper"

RSpec.describe Message, type: :model do
  let(:user) { User.create!(name: "User", email: "user-msg@example.com", password: "password", password_confirmation: "password") }
  let(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: user) }

  it "is valid with content" do
    message = described_class.new(content: "Hello", user: user, rv_listing: listing)
    expect(message).to be_valid
  end

  it "requires content" do
    message = described_class.new(content: nil, user: user, rv_listing: listing)
    expect(message).not_to be_valid
  end
end
