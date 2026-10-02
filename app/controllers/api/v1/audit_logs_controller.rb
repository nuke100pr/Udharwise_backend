require "csv"

module Api
  module V1
    class AuditLogsController < ApplicationController
      before_action :authenticate_user!

      def index
        group = current_user.groups.find(params[:group_id])
        logs = group.audit_logs.includes(:actor).order(created_at: :desc).limit(100)

        render json: logs.map { |log| serialize_log(log) }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "group_not_found_or_not_a_member" }, status: :not_found
      end

      def export
        group = current_user.groups.find(params[:group_id])
        logs = group.audit_logs.includes(:actor).order(created_at: :asc)

        csv = CSV.generate(headers: true) do |out|
          out << [
            "id",
            "created_at",
            "action",
            "entity_type",
            "entity_id",
            "actor_id",
            "actor_handle",
            "metadata"
          ]

          logs.each do |log|
            out << [
              log.id,
              log.created_at,
              log.action,
              log.entity_type,
              log.entity_id,
              log.actor_id,
              log.actor.handle,
              log.metadata.to_json
            ]
          end
        end

        ::AuditLogger.record(
          group: group,
          actor: current_user,
          action: "audit_logs.export_csv",
          entity: group,
          metadata: { format: "csv", log_count: logs.size }
        )

        send_data csv,
                  filename: "group-#{group.id}-audit-logs.csv",
                  type: "text/csv",
                  disposition: "attachment"
      rescue ActiveRecord::RecordNotFound
        render json: { error: "group_not_found_or_not_a_member" }, status: :not_found
      end

      private

      def serialize_log(log)
        {
          id: log.id,
          action: log.action,
          entity_type: log.entity_type,
          entity_id: log.entity_id,
          metadata: log.metadata,
          actor: { id: log.actor_id, handle: log.actor.handle },
          created_at: log.created_at
        }
      end
    end
  end
end
