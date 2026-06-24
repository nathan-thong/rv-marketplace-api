require "rails_helper"

RSpec.describe RvListing, type: :model do
  let(:user) do
    User.create!(
      name: "Owner",
      email: unique_email("owner-l"),
      password: "password",
      password_confirmation: "password"
    )
  end

  it "is valid with required attributes" do
    listing = described_class.new(
      title: "RV",
      description: "Nice",
      location: "Sydney",
      price_per_day: 100,
      user: user
    )

    expect(listing).to be_valid
  end

  it "requires title" do
    listing = described_class.new(
      description: "Nice",
      location: "Sydney",
      price_per_day: 100,
      user: user
    )

    expect(listing).not_to be_valid
  end

  it "requires description" do
    listing = described_class.new(
      title: "RV",
      location: "Sydney",
      price_per_day: 100,
      user: user
    )

    expect(listing).not_to be_valid
  end

  it "requires location" do
    listing = described_class.new(
      title: "RV",
      description: "Nice",
      price_per_day: 100,
      user: user
    )

    expect(listing).not_to be_valid
  end

  it "requires price_per_day" do
    listing = described_class.new(
      title: "RV",
      description: "Nice",
      location: "Sydney",
      user: user
    )

    expect(listing).not_to be_valid
  end

  it "requires an owner" do
    listing = described_class.new(
      title: "RV",
      description: "Nice",
      location: "Sydney",
      price_per_day: 100
    )

    expect(listing).not_to be_valid
  end

  it "rejects zero price_per_day" do
    listing = described_class.new(
      title: "RV",
      description: "Nice",
      location: "Sydney",
      price_per_day: 0,
      user: user
    )

    expect(listing).not_to be_valid
  end

  it "rejects negative price_per_day" do
    listing = described_class.new(
      title: "RV",
      description: "Nice",
      location: "Sydney",
      price_per_day: -50,
      user: user
    )

    expect(listing).not_to be_valid
  end

  it "belongs to a user" do
    expect(described_class.reflect_on_association(:user).macro)
      .to eq(:belongs_to)
  end
end
