class Expense < ApplicationRecord
  belongs_to :group
  belongs_to :created_by, class_name: "User"
  has_many :expense_participants, dependent: :destroy
  has_many :participants, through: :expense_participants, source: :user

  validates :total_paise, presence: true,
                          numericality: { only_integer: true, greater_than: 0 }

  def archived?
    archived_at.present?
  end
end
