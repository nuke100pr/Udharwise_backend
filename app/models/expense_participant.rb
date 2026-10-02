class ExpenseParticipant < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :share_paise, :paid_paise,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :expense_id }

  # Derived — not stored. 0 when this person has already covered their share.
  def owed_paise
    [share_paise - paid_paise, 0].max
  end

  def covered?
    paid_paise >= share_paise
  end
end
