require "csv"

module Api
  module V1
    class GroupExportsController < ApplicationController
      before_action :authenticate_user!

      def show
        group = current_user.groups.find(params[:group_id])
        expenses = group.expenses.includes(:created_by, expense_participants: :user).order(:id)

        csv = CSV.generate(headers: true) do |out|
          out << [
            "expense_id",
            "description",
            "total_paise",
            "created_by_handle",
            "archived_at",
            "user_id",
            "user_handle",
            "share_paise",
            "paid_paise",
            "owed_paise"
          ]

          expenses.each do |expense|
            expense.expense_participants.each do |p|
              owed = [p.share_paise - p.paid_paise, 0].max
              out << [
                expense.id,
                expense.description,
                expense.total_paise,
                expense.created_by.handle,
                expense.archived_at,
                p.user_id,
                p.user.handle,
                p.share_paise,
                p.paid_paise,
                owed
              ]
            end
          end
        end

        ::AuditLogger.record(
          group: group,
          actor: current_user,
          action: "export_csv",
          entity: group,
          metadata: { format: "csv", expense_count: expenses.size }
        )

        send_data csv,
                  filename: "group-#{group.id}-expenses.csv",
                  type: "text/csv",
                  disposition: "attachment"
      rescue ActiveRecord::RecordNotFound
        render json: { error: "group_not_found_or_not_a_member" }, status: :not_found
      end
    end
  end
end
