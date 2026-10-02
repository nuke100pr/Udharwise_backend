class AuditLog < ApplicationRecord
  belongs_to :group
  belongs_to :actor, class_name: "User"

  validates :action, :entity_type, presence: true
end
