class AuditLog {
  final String id;
  final DateTime timestamp;
  final String actorType; // 'student', 'admin', 'system'
  final String actorId;
  final String action; // 'CARD_SCANNED', 'BOOK_BORROWED', 'BOOK_RETURNED', 'TAG_WRITTEN', etc.
  final String entityType; // 'book', 'copy', 'member', 'card', 'fine'
  final String entityId;
  final String details;

  AuditLog({
    required this.id,
    DateTime? timestamp,
    required this.actorType,
    required this.actorId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'actor_type': actorType,
      'actor_id': actorId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      actorType: map['actor_type'] as String,
      actorId: map['actor_id'] as String,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      details: map['details'] as String,
    );
  }
}
