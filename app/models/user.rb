class User < ApplicationRecord
  has_secure_password validations: false

  before_validation :normalize_identity

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true, uniqueness: true
  validates :handle, presence: true, uniqueness: true,
                    format: { with: /\A[a-z0-9_]+\z/, message: "can only contain lowercase letters, numbers, and underscores" }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :password, presence: true, on: :signup

  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships, source: :group
  has_many :created_groups, class_name: "Group", foreign_key: "created_by_id", inverse_of: :created_by

  def password_set?
    password_digest.present?
  end

  private

  def normalize_identity
    self.email = email.to_s.strip.downcase if email.present?
    self.handle = handle.to_s.strip.downcase.delete_prefix("@") if handle.present?
    self.phone = phone.to_s.strip if phone.present?
  end
end
