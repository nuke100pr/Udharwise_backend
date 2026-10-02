class ExpenseParticipant < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :share_paise, :paid_paise,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :expense_id }

  def settled?
    settled_at.present?
  end

  # How much this person still owes on this expense (0 if they overpaid / are even)
  def owed_paise
    [share_paise - paid_paise, 0].max
  end
end
