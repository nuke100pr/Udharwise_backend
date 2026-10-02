module Api
  module V1
    class InvitesController < ApplicationController
      before_action :authenticate_user!


      def index
        invites = ::GroupInvite
          .where(invitee_id: current_user.id, status: "pending")
          .includes(:group, :inviter)
          .order(created_at: :desc)

        render json: invites.map { |invite|
          {
            id: invite.id,
            status: invite.status,
            created_at: invite.created_at,
            group: {
              id: invite.group_id,
              name: invite.group.name,
              archived_at: invite.group.archived_at
            },
            inviter: { id: invite.inviter_id, handle: invite.inviter.handle }
          }
        }
      end

      def accept
        invite = ::GroupInvite.find(params[:id])
        return render json: { error: "forbidden" }, status: :forbidden unless invite.invitee_id == current_user.id
        return render json: { error: "invite_not_pending" }, status: :unprocessable_entity unless invite.status == "pending"
        return render json: { error: "group_archived" }, status: :unprocessable_entity if invite.group.archived?

        ActiveRecord::Base.transaction do
          invite.update!(status: "accepted")
          invite.group.group_memberships.create!(user: current_user)
        end

        ::AuditLogger.record(
          group: invite.group,
          actor: current_user,
          action: "invite.accept",
          entity: invite
        )

        render json: { message: "accepted", group_id: invite.group_id }, status: :ok
      end

      def decline
        invite = ::GroupInvite.find(params[:id])
        return render json: { error: "forbidden" }, status: :forbidden unless invite.invitee_id == current_user.id
        return render json: { error: "invite_not_pending" }, status: :unprocessable_entity unless invite.status == "pending"

        invite.update!(status: "declined")

        ::AuditLogger.record(
          group: invite.group,
          actor: current_user,
          action: "invite.decline",
          entity: invite
        )

        render json: { message: "declined", group_id: invite.group_id }, status: :ok
      end
    end
  end
end
