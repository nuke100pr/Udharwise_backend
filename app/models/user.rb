class User < ApplicationRecord

  validates :email, presence: true, uniqueness: true
  validates :phone, presence: true, uniqueness: true
  validates :handle, presence: true, uniqueness: true,
                    format: { with: /\A[a-z0-9_]+\z/i, message: "can only contain letters, numbers, and underscores" }

  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships, source: :group
  has_many :created_groups, class_name: "Group", foreign_key: "created_by_id", inverse_of: :created_by                  

end
