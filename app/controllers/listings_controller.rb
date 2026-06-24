class ListingsController < ApplicationController
  include Authenticable

  before_action :authenticate_user!, only: [ :create, :update, :destroy ]
  before_action :set_listing, only: [ :show, :update, :destroy ]
  before_action :authorize_owner!, only: [ :update, :destroy ]

  # GET /listings
  def index
    listings = RvListing.all
    render json: listings, status: :ok
  end

  # GET /listings/:id
  def show
    render json: @listing, status: :ok
  end

  # POST /listings
  def create
    listing = current_user.rv_listings.build(listing_params)
    if listing.save
      render json: listing, status: :created
    else
      render json: { errors: listing.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /listings/:id
  def update
    if @listing.update(listing_params)
      render json: @listing, status: :ok
    else
      render json: { errors: @listing.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /listings/:id
  def destroy
    @listing.destroy
    render json: { message: "Listing deleted successfully" }, status: :ok
  end

  private

  def set_listing
    @listing = RvListing.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Listing not found" }, status: :not_found
  end

  def authorize_owner!
    return if @listing.user_id == current_user.id

    render json: { error: "Unauthorized" }, status: :forbidden
  end

  def listing_params
    params.require(:rv_listing).permit(:title, :description, :location, :price_per_day)
  end
end
