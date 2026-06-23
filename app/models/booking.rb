class Booking < ApplicationRecord
  STATUSES = %w[pending confirmed rejected].freeze

  belongs_to :user
  belongs_to :rv_listing

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end
end
