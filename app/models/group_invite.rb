class GroupInvite < ApplicationRecord
  belongs_to :group
  belongs_to :inviter ,class_name: "User"
  belongs_to :invitee ,class_name: "User"

  STATUSES = ["pending", "accepted", "declined"]
  validates :status, presence: true, inclusion: { in: STATUSES }
end
