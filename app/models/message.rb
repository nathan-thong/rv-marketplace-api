class Message < ApplicationRecord
  belongs_to :user
  belongs_to :rv_listing
  belongs_to :recipient, class_name: "User"

  validates :content, presence: true
  validate :recipient_is_not_sender

  private

  def recipient_is_not_sender
    errors.add(:recipient, "can't be the sender") if recipient_id.present? && recipient_id == user_id
  end
end
