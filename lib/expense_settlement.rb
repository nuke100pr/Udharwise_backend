# Settling adjusts paid_paise on the expense split so balances stay derived
# from share/paid only — nothing else is stored.
class ExpenseSettlement
  class Error < StandardError; end

  # Returns { owed_paise:, allocations: [{ to_user_id:, amount_paise: }, ...] }
  def self.apply!(expense, user)
    participant = expense.expense_participants.find_by!(user_id: user.id)
    owed = [participant.share_paise - participant.paid_paise, 0].max
    raise Error, "already_settled" if owed <= 0

    remaining = owed
    allocations = []
    creditors = expense.expense_participants
      .select { |p| p.paid_paise > p.share_paise }
      .sort_by { |p| -(p.paid_paise - p.share_paise) }

    raise Error, "no_creditor_to_settle_against" if creditors.empty?

    ActiveRecord::Base.transaction do
      creditors.each do |creditor|
        break if remaining <= 0
        excess = creditor.paid_paise - creditor.share_paise
        take = [excess, remaining].min
        next if take <= 0

        creditor.update!(paid_paise: creditor.paid_paise - take)
        allocations << { to_user_id: creditor.user_id, amount_paise: take }
        remaining -= take
      end

      raise Error, "unable_to_fully_settle" if remaining.positive?

      participant.update!(paid_paise: participant.share_paise)

      total_paid = expense.expense_participants.reload.sum(:paid_paise)
      unless total_paid == expense.total_paise
        raise Error, "paid_total_mismatch"
      end
    end

    { owed_paise: owed, allocations: allocations }
  end

  # Settle every open share for +user+ in +group+. Returns summary with payees.
  def self.apply_all!(group, user)
    payees = Hash.new(0)
    settled = []

    ActiveRecord::Base.transaction do
      group.expenses.where(archived_at: nil).includes(:expense_participants).find_each do |expense|
        participant = expense.expense_participants.find { |p| p.user_id == user.id }
        next unless participant
        next if participant.owed_paise <= 0

        result = apply!(expense, user)
        settled << {
          expense_id: expense.id,
          description: expense.description,
          owed_paise: result[:owed_paise]
        }
        result[:allocations].each do |row|
          payees[row[:to_user_id]] += row[:amount_paise]
        end
      end
    end

    users_by_id = group.users.index_by(&:id)
    {
      settled_count: settled.size,
      total_paise: settled.sum { |row| row[:owed_paise] },
      expenses: settled,
      payees: payees.map { |user_id, amount_paise|
        {
          user_id: user_id,
          handle: users_by_id[user_id]&.handle,
          amount_paise: amount_paise
        }
      }.sort_by { |row| -row[:amount_paise] }
    }
  end
end
