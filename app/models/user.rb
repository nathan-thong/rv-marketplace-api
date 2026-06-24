class User < ApplicationRecord
  has_many :rv_listings, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :messages, dependent: :destroy

  has_secure_password

  before_validation :normalize_email

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
