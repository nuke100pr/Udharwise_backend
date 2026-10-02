class GroupBalanceCalculator
  def self.nets_for(group)
    nets = Hash.new(0)

    group.expenses.where(archived_at: nil).includes(:expense_participants).find_each do |expense|
      expense.expense_participants.each do |p|
        next if p.settled?

        nets[p.user_id] += p.paid_paise - p.share_paise
      end
    end

    nets
  end

  # Greedy debt simplification: minimal transfers that clear open nets.
  # Returns array of { from_user_id:, to_user_id:, amount_paise: }
  def self.simplify(group)
    nets = nets_for(group)

    debtors = []
    creditors = []

    nets.each do |user_id, amount|
      if amount.negative?
        debtors << [user_id, -amount]
      elsif amount.positive?
        creditors << [user_id, amount]
      end
    end

    debtors.sort_by! { |(_, amount)| -amount }
    creditors.sort_by! { |(_, amount)| -amount }

    transfers = []
    i = 0
    j = 0

    while i < debtors.length && j < creditors.length
      from_id, owe = debtors[i]
      to_id, due = creditors[j]
      pay = [owe, due].min

      transfers << { from_user_id: from_id, to_user_id: to_id, amount_paise: pay }

      debtors[i][1] -= pay
      creditors[j][1] -= pay
      i += 1 if debtors[i][1].zero?
      j += 1 if creditors[j][1].zero?
    end

    transfers
  end
end
