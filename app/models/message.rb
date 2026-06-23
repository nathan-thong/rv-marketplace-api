class Message < ApplicationRecord
  belongs_to :user
  belongs_to :rv_listing

  validates :content, presence: true
end
