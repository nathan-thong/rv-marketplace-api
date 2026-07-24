class Booking < ApplicationRecord
  STATUSES = %w[pending confirmed rejected].freeze

  belongs_to :user
  belongs_to :rv_listing

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :end_date_after_start_date
  validate :no_overlapping_booking

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end

  def no_overlapping_booking
    return unless rv_listing_id && start_date && end_date

    overlap = Booking.where(rv_listing_id: rv_listing_id, status: %w[pending confirmed])
                      .where.not(id: id)
                      .where("start_date < ? AND end_date > ?", end_date, start_date)
                      .exists?

    errors.add(:base, "These dates are not available for this listing") if overlap
  end
end
