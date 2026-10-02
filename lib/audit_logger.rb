class AuditLogger
  def self.record(group:, actor:, action:, entity:, metadata: {})
    ::AuditLog.create!(
      group: group,
      actor: actor,
      action: action,
      entity_type: entity.class.name,
      entity_id: entity.id,
      metadata: metadata
    )
  end
end
