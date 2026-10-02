module Api
  module V1
    class GroupsController < ApplicationController
      before_action :authenticate_user!

      def index
        groups = current_user.groups.order(created_at: :desc)
        render json: groups.as_json(only: [:id, :name, :description, :archived_at, :created_by_id, :created_at])
      end

      def create
        group = ::Group.new(
          name: params.require(:name),
          description: params[:description],
          created_by: current_user
        )

        ActiveRecord::Base.transaction do
          group.save!
          group.group_memberships.create!(user: current_user)
        end

        ::AuditLogger.record(
          group: group,
          actor: current_user,
          action: "group.create",
          entity: group,
          metadata: { name: group.name }
        )

        render json: group.as_json(only: [:id, :name, :description, :archived_at, :created_by_id, :created_at]),
               status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end

      def archive
        group = current_user.groups.find(params[:id])
        group.update!(archived_at: Time.current)
        ::AuditLogger.record(group: group, actor: current_user, action: "group.archive", entity: group)
        render json: group.as_json(only: [:id, :name, :archived_at])
      end

      def unarchive
        group = current_user.groups.find(params[:id])
        group.update!(archived_at: nil)
        ::AuditLogger.record(group: group, actor: current_user, action: "group.unarchive", entity: group)
        render json: group.as_json(only: [:id, :name, :archived_at])
      end

      def balances
        group = current_user.groups.find(params[:id])
        nets = ::GroupBalanceCalculator.nets_for(group)

        result = group.users.map do |user|
          {
            user_id: user.id,
            handle: user.handle,
            balance_paise: nets[user.id]
          }
        end

        render json: { group_id: group.id, balances: result }
      end

      def simplify
        group = current_user.groups.find(params[:id])
        nets = ::GroupBalanceCalculator.nets_for(group)
        transfers = ::GroupBalanceCalculator.simplify(group)
        users_by_id = group.users.index_by(&:id)

        render json: {
          group_id: group.id,
          balances: group.users.map { |u|
            { user_id: u.id, handle: u.handle, balance_paise: nets[u.id] }
          },
          transfers: transfers.map { |t|
            {
              from_user_id: t[:from_user_id],
              from_handle: users_by_id[t[:from_user_id]]&.handle,
              to_user_id: t[:to_user_id],
              to_handle: users_by_id[t[:to_user_id]]&.handle,
              amount_paise: t[:amount_paise]
            }
          }
        }
      end
    end
  end
end
