class User < ApplicationRecord
  has_many :rv_listings, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :messages, dependent: :destroy

  has_secure_password

  before_save :downcase_email

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def downcase_email
    email.downcase!
  end
end
