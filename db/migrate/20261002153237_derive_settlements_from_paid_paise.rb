class DeriveSettlementsFromPaidPaise < ActiveRecord::Migration[8.1]
  class MigrationExpense < ActiveRecord::Base
    self.table_name = "expenses"
    has_many :expense_participants, class_name: "MigrationParticipant", foreign_key: "expense_id"
  end

  class MigrationParticipant < ActiveRecord::Base
    self.table_name = "expense_participants"
  end

  def up
    MigrationExpense.includes(:expense_participants).find_each do |expense|
      expense.expense_participants.each do |participant|
        next if participant.settled_at.blank?

        owed = [participant.share_paise - participant.paid_paise, 0].max
        next if owed <= 0

        remaining = owed
        creditors = expense.expense_participants
          .select { |p| p.id != participant.id && p.paid_paise > p.share_paise }
          .sort_by { |p| -(p.paid_paise - p.share_paise) }

        creditors.each do |creditor|
          break if remaining <= 0
          excess = creditor.paid_paise - creditor.share_paise
          take = [excess, remaining].min
          next if take <= 0

          creditor.update_columns(paid_paise: creditor.paid_paise - take)
          remaining -= take
        end

        if remaining <= 0
          participant.update_columns(paid_paise: participant.share_paise)
        end
      end
    end

    remove_column :expense_participants, :settled_at, :datetime
  end

  def down
    add_column :expense_participants, :settled_at, :datetime
  end
end
