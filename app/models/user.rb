class User < ApplicationRecord
  has_many :rv_listings, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
