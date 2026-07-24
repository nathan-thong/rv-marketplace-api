class MessagesController < ApplicationController
  include Authenticable

  before_action :authenticate_user!
  before_action :set_listing

  rescue_from ActionController::ParameterMissing, with: :render_missing_recipient

  # GET /listings/:listing_id/messages
  def index
    messages = thread_scope.order(created_at: :asc)
    render json: messages.as_json(only: [ :id, :content, :created_at, :updated_at, :user_id, :recipient_id ]), status: :ok
  end

  # POST /listings/:listing_id/messages
  def create
    message = @listing.messages.build(message_params)
    message.user = current_user
    message.recipient_id = resolve_recipient_id

    if message.save
      render json: message.as_json(only: [ :id, :content, :created_at, :updated_at, :user_id, :recipient_id ]), status: :created
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

  def thread_scope
    if @listing.user_id == current_user.id
      @listing.messages
    else
      @listing.messages.where(user_id: current_user.id).or(@listing.messages.where(recipient_id: current_user.id))
    end
  end

  def resolve_recipient_id
    return @listing.user_id unless @listing.user_id == current_user.id

    params.require(:message).require(:recipient_id)
  end

  def render_missing_recipient
    render json: { errors: { recipient_id: [ "is required when replying as the listing owner" ] } }, status: :unprocessable_entity
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
