class Group < ApplicationRecord
  belongs_to :created_by , class_name: "User"
  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships , source: :user
  has_many :group_invites, dependent: :destroy

  validates :name, presence: true

  def archived?
    archived_at.present?
  end

  has_many :expenses, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
end
