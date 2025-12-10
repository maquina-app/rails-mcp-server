class User < ApplicationRecord
  has_many :posts
  has_many :comments
  belongs_to :organization

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }

  before_save :normalize_email
  after_create :send_welcome_email

  enum :role, {user: 0, admin: 1, moderator: 2}

  private

  def normalize_email
    self.email = email.downcase
  end

  def send_welcome_email
    # Implementation
  end
end
