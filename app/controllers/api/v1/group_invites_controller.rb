module Api
  module V1
    class GroupInvitesController < ApplicationController
      before_action :authenticate_user!


      def index
        group = current_user.groups.find(params.require(:group_id))
        invites = group.group_invites.includes(:invitee, :inviter).order(created_at: :desc)
        render json: invites.map { |invite|
          {
            id: invite.id,
            status: invite.status,
            created_at: invite.created_at,
            inviter: { id: invite.inviter_id, handle: invite.inviter.handle },
            invitee: { id: invite.invitee_id, handle: invite.invitee.handle }
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "group_not_found_or_not_a_member" }, status: :not_found
      end

      def create
        group = current_user.groups.find(params.require(:group_id))
        return render json: { error: "group_archived" }, status: :unprocessable_entity if group.archived?

        handle = params.require(:handle).to_s.strip.downcase.delete_prefix("@")
        invitee = ::User.find_by!(handle: handle)

        if group.users.exists?(invitee.id)
          return render json: { error: "user_already_member" }, status: :unprocessable_entity
        end

        invite = group.group_invites.create!(inviter: current_user, invitee: invitee, status: "pending")

        ::AuditLogger.record(
          group: group,
          actor: current_user,
          action: "invite.create",
          entity: invite,
          metadata: { invitee_id: invitee.id, handle: invitee.handle }
        )

        render json: {
          id: invite.id,
          status: invite.status,
          invitee: {
            id: invitee.id,
            handle: invitee.handle
          }
        }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "not_found" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end
  end
end