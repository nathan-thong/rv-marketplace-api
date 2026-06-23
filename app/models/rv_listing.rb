class RvListing < ApplicationRecord
  belongs_to :user
  has_many :bookings, dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :title, presence: true
  validates :description, presence: true
  validates :location, presence: true
  validates :price_per_day, presence: true, numericality: { greater_than: 0 }
end
