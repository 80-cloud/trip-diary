class User < ApplicationRecord
  has_secure_password

  has_many :trips, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :liked_trips, through: :likes, source: :trip
  has_one_attached :avatar

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { in: 1..30 }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  before_save { self.email = email.downcase.strip }
end
