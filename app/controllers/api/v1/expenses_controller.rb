module Api
  module V1
    class ExpensesController < ApplicationController
      before_action :authenticate_user!

      def index
        group = current_user.groups.find(params[:group_id])
        expenses = group.expenses.includes(:expense_participants).order(created_at: :desc)
        render json: expenses.map { |expense| serialize_expense(expense) }
      end

      def create
        group = current_user.groups.find(params[:group_id])
        return render json: { error: "group_archived" }, status: :forbidden if group.archived?

        participants_params = params.require(:participants)
        total_paise = params.require(:total_paise).to_i

        expense = nil
        ActiveRecord::Base.transaction do
          expense = group.expenses.create!(
            description: params[:description],
            total_paise: total_paise,
            created_by: current_user
          )

          participants_params.each do |p|
            user_id = p[:user_id] || p["user_id"]
            unless group.users.exists?(id: user_id)
              expense.errors.add(:base, "participant must be a group member")
              raise ActiveRecord::RecordInvalid, expense
            end

            expense.expense_participants.create!(
              user_id: user_id,
              share_paise: (p[:share_paise] || p["share_paise"]).to_i,
              paid_paise: (p[:paid_paise] || p["paid_paise"]).to_i
            )
          end

          shares = expense.expense_participants.sum(:share_paise)
          paid = expense.expense_participants.sum(:paid_paise)
          has_payer = expense.expense_participants.any? { |row| row.paid_paise.positive? }

          unless shares == total_paise && paid == total_paise && has_payer
            expense.errors.add(:base, "shares and paid must equal total_paise, and someone must pay")
            raise ActiveRecord::RecordInvalid, expense
          end
        end

        ::AuditLogger.record(
          group: group,
          actor: current_user,
          action: "expense.create",
          entity: expense,
          metadata: { total_paise: expense.total_paise, description: expense.description }
        )

        render json: serialize_expense(expense), status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "group_not_found_or_not_a_member" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def archive
        group = current_user.groups.find(params[:group_id])
        return render json: { error: "group_archived" }, status: :forbidden if group.archived?

        expense = group.expenses.find(params[:id])
        expense.update!(archived_at: Time.current)
        ::AuditLogger.record(group: group, actor: current_user, action: "expense.archive", entity: expense)
        render json: expense.as_json(only: [:id, :description, :archived_at])
      end

      def unarchive
        group = current_user.groups.find(params[:group_id])
        return render json: { error: "group_archived" }, status: :forbidden if group.archived?

        expense = group.expenses.find(params[:id])
        expense.update!(archived_at: nil)
        ::AuditLogger.record(group: group, actor: current_user, action: "expense.unarchive", entity: expense)
        render json: expense.as_json(only: [:id, :description, :archived_at])
      end

      # Settle by adjusting paid_paise on the split (source of truth). Balances recalculate.
      def settle_share
        group = current_user.groups.find(params[:group_id])
        return render json: { error: "group_archived" }, status: :forbidden if group.archived?

        expense = group.expenses.find(params[:id])
        return render json: { error: "expense_archived" }, status: :forbidden if expense.archived?

        result = ::ExpenseSettlement.apply!(expense, current_user)

        ::AuditLogger.record(
          group: group,
          actor: current_user,
          action: "expense.settle_share",
          entity: expense,
          metadata: {
            user_id: current_user.id,
            settled_owed_paise: result[:owed_paise],
            allocations: result[:allocations]
          }
        )

        render json: {
          message: "share_settled",
          expense_id: expense.id,
          user_id: current_user.id,
          settled_owed_paise: result[:owed_paise],
          allocations: result[:allocations],
          expense: serialize_expense(expense.reload)
        }
      rescue ::ExpenseSettlement::Error => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "not_found" }, status: :not_found
      end

      private

      def serialize_expense(expense)
        {
          id: expense.id,
          description: expense.description,
          total_paise: expense.total_paise,
          archived_at: expense.archived_at,
          created_by_id: expense.created_by_id,
          created_at: expense.created_at,
          expense_participants: expense.expense_participants.map { |p|
            {
              user_id: p.user_id,
              share_paise: p.share_paise,
              paid_paise: p.paid_paise,
              owed_paise: p.owed_paise
            }
          }
        }
      end
    end
  end
end
