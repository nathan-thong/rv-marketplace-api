require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with required attributes" do
    user = described_class.new(
      name: "Jane",
      email: "jane-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      password_confirmation: "password"
    )
    expect(user).to be_valid
  end

  it "requires name" do
    user = described_class.new(
      email: "jane-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      password_confirmation: "password"
    )
    expect(user).not_to be_valid
  end

  it "requires unique email" do
    email = "jane-#{SecureRandom.hex(4)}@example.com"
    described_class.create!(name: "Jane", email: email, password: "password", password_confirmation: "password")
    dup = described_class.new(name: "Jane 2", email: email, password: "password", password_confirmation: "password")
    expect(dup).not_to be_valid
  end
end
