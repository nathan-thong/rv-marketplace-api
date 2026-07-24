require "rails_helper"

RSpec.describe Message, type: :model do
  let(:user) { User.create!(name: "User", email: unique_email("user-msg"), password: "password", password_confirmation: "password") }
  let(:owner) { User.create!(name: "Owner", email: unique_email("owner-msg"), password: "password", password_confirmation: "password") }
  let(:listing) { RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "is valid with content and a recipient" do
    message = described_class.new(content: "Hello", user: user, rv_listing: listing, recipient: owner)
    expect(message).to be_valid
  end

  it "requires content" do
    message = described_class.new(content: nil, user: user, rv_listing: listing, recipient: owner)
    expect(message).not_to be_valid
  end

  it "requires a recipient" do
    message = described_class.new(content: "Hello", user: user, rv_listing: listing)
    expect(message).not_to be_valid
  end

  it "rejects a recipient that is the same as the sender" do
    message = described_class.new(content: "Hello", user: user, rv_listing: listing, recipient: user)
    expect(message).not_to be_valid
    expect(message.errors[:recipient]).to include("can't be the sender")
  end
end
