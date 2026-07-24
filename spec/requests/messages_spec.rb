require "rails_helper"

RSpec.describe "Messages", type: :request do
  let!(:owner) { User.create!(name: "Owner", email: unique_email("owner-m"), password: "password", password_confirmation: "password") }
  let!(:user) { User.create!(name: "User", email: unique_email("user-m"), password: "password", password_confirmation: "password") }
  let!(:stranger) { User.create!(name: "Stranger", email: unique_email("stranger-m"), password: "password", password_confirmation: "password") }
  let!(:listing) { RvListing.create!(title: "RV One", description: "Nice", location: "Sydney", price_per_day: 100, user: owner) }

  it "allows any authenticated user to create a message, deriving the owner as recipient" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Is this available?" } },
      headers: auth_headers(user),
      as: :json

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["user_id"]).to eq(user.id)
    expect(body["recipient_id"]).to eq(owner.id)
    expect(body["sender_name"]).to eq(user.name)
    expect(body["recipient_name"]).to eq(owner.name)
  end

  it "ignores a client-supplied recipient_id for a non-owner sender" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Is this available?", recipient_id: stranger.id } },
      headers: auth_headers(user),
      as: :json

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)["recipient_id"]).to eq(owner.id)
  end

  it "requires recipient_id when the owner is replying" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Sure, it's available" } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "lets the owner reply to a participant who has already messaged the listing" do
    Message.create!(content: "Is this available?", user: user, rv_listing: listing, recipient: owner)

    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Sure, it's available", recipient_id: user.id } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)["recipient_id"]).to eq(user.id)
  end

  it "blocks the owner from replying to a user who has never messaged the listing" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Hey, want to book?", recipient_id: stranger.id } },
      headers: auth_headers(owner),
      as: :json

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body["errors"]["recipient_id"]).to include("must be a user who has already messaged this listing")
  end

  it "blocks unauthenticated users from creating messages" do
    post "/listings/#{listing.id}/messages",
      params: { message: { content: "Is this available?" } },
      as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "blocks unauthenticated users from listing messages" do
    get "/listings/#{listing.id}/messages"
    expect(response).to have_http_status(:unauthorized)
  end

  describe "thread scoping and privacy" do
    let!(:user_message) do
      Message.create!(content: "Is this available?", user: user, rv_listing: listing, recipient: owner)
    end

    let!(:stranger_message) do
      Message.create!(content: "Can I get a discount?", user: stranger, rv_listing: listing, recipient: owner)
    end

    it "lets the listing owner see every thread on their listing" do
      get "/listings/#{listing.id}/messages", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |m| m["id"] }
      expect(ids).to contain_exactly(user_message.id, stranger_message.id)
    end

    it "only lets a participant see their own thread, not other users' messages on the same listing" do
      get "/listings/#{listing.id}/messages", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |m| m["id"] }
      expect(ids).to contain_exactly(user_message.id)
      expect(ids).not_to include(stranger_message.id)
    end

    it "never includes email anywhere in the response body" do
      get "/listings/#{listing.id}/messages", headers: auth_headers(owner)

      expect(response.body).not_to include("email")
      expect(response.body).not_to include(owner.email)
      expect(response.body).not_to include(user.email)
    end
  end
end
