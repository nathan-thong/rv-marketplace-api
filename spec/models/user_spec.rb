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
end
