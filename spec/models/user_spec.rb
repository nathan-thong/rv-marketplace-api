require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with required attributes" do
    user = described_class.new(
      name: "Jane",
      email: unique_email("jane"),
      password: "password",
      password_confirmation: "password"
    )
    expect(user).to be_valid
  end

  it "requires name" do
    user = described_class.new(
      email: unique_email("jane"),
      password: "password",
      password_confirmation: "password"
    )
    expect(user).not_to be_valid
  end

  it "requires unique email" do
    email = unique_email("jane")
    described_class.create!(name: "Jane", email: email, password: "password", password_confirmation: "password")
    dup = described_class.new(name: "Jane 2", email: email, password: "password", password_confirmation: "password")
    expect(dup).not_to be_valid
  end

  it "downcases the email before validation" do
    user = described_class.new(
      name: "Owner",
      email: "Owner@Example.COM",
      password: "password123",
      password_confirmation: "password123"
    )

    user.valid?

    expect(user.email).to eq("owner@example.com")
  end

  it "validates email uniqueness case-insensitively" do
    base_email = unique_email("owner")

    described_class.create!(
      name: "Owner",
      email: base_email,
      password: "password123",
      password_confirmation: "password123"
    )

    duplicate = described_class.new(
      name: "Other Owner",
      email: base_email.upcase,
      password: "password123",
      password_confirmation: "password123"
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "destroys messages where the user is only the recipient, not the sender" do
    owner = described_class.create!(name: "Owner", email: unique_email("owner-destroy"), password: "password", password_confirmation: "password")
    renter = described_class.create!(name: "Renter", email: unique_email("renter-destroy"), password: "password", password_confirmation: "password")
    listing = RvListing.create!(title: "RV", description: "Nice", location: "Sydney", price_per_day: 100, user: owner)
    # Owner replying to renter: renter is the recipient here, never the sender,
    # so this can only be cascade-deleted via the received_messages association -
    # not via the listing (owned by `owner`, untouched) or `renter`'s own `messages`.
    message = Message.create!(content: "Sure, it's available", user: owner, rv_listing: listing, recipient: renter)

    expect { renter.destroy }.to change { Message.exists?(message.id) }.from(true).to(false)
  end
end
