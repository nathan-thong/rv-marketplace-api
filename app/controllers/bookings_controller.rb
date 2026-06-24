class BookingsController < ApplicationController
  include Authenticable

  before_action :authenticate_user!
  before_action :set_listing, only: [ :create ]
  before_action :set_booking, only: [ :confirm, :reject ]
  before_action :authorize_listing_owner!, only: [ :confirm, :reject ]

  # POST /listings/:listing_id/bookings
  def create
    # User cannot book their own listing
    if @listing.user_id == current_user.id
      return render json: { error: "Cannot book your own listing" }, status: :forbidden
    end

    booking = @listing.bookings.build(booking_params)
    booking.user = current_user

    if booking.save
      render json: booking, status: :created
    else
      render json: { errors: booking.errors }, status: :unprocessable_entity
    end
  end

  # GET /bookings
  def index
    # Return bookings where current_user is the hirer OR owner of the listing
    bookings = Booking.where(user_id: current_user.id).or(
      Booking.where(rv_listing_id: RvListing.where(user_id: current_user.id).select(:id))
    )
    render json: bookings, status: :ok
  end

  # PATCH /bookings/:id/confirm
  def confirm
    if @booking.update(status: "confirmed")
      render json: @booking, status: :ok
    else
      render json: { errors: @booking.errors }, status: :unprocessable_entity
    end
  end

  # PATCH /bookings/:id/reject
  def reject
    if @booking.update(status: "rejected")
      render json: @booking, status: :ok
    else
      render json: { errors: @booking.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_listing
    @listing = RvListing.find(params[:listing_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Listing not found" }, status: :not_found
  end

  def set_booking
    @booking = Booking.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Booking not found" }, status: :not_found
  end

  def authorize_listing_owner!
    return if @booking.rv_listing.user_id == current_user.id

    render json: { error: "Unauthorized" }, status: :forbidden
  end

  def booking_params
    params.require(:booking).permit(:start_date, :end_date)
  end
end
