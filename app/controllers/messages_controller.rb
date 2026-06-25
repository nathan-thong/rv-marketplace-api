class MessagesController < ApplicationController
  include Authenticable

  before_action :authenticate_user!
  before_action :set_listing

  # GET /listings/:listing_id/messages
  def index
    messages = @listing.messages.includes(:user).order(created_at: :asc)
    render json: messages.as_json(
      only: [ :id, :content, :created_at, :updated_at ],
      include: { user: { only: [ :id, :name, :email ] } }
    ), status: :ok
  end

  # POST /listings/:listing_id/messages
  def create
    message = @listing.messages.build(message_params)
    message.user = current_user

    if message.save
      render json: message.as_json(
        only: [ :id, :content, :created_at, :updated_at ],
        include: { user: { only: [ :id, :name, :email ] } }
      ), status: :created
    else
      render json: { errors: message.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_listing
    @listing = RvListing.find(params[:listing_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Listing not found" }, status: :not_found
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
