class RfidCardRecord {
  final String id;
  final String memberId;
  final String epc;
  final String cardType; // 'student', 'librarian', 'admin'
  final String status; // 'active', 'blocked', 'lost'
  final DateTime issuedAt;
  final DateTime? lastUsedAt;

  RfidCardRecord({
    required this.id,
    required this.memberId,
    required this.epc,
    this.cardType = 'student',
    this.status = 'active',
    DateTime? issuedAt,
    this.lastUsedAt,
  }) : issuedAt = issuedAt ?? DateTime.now();

  bool get isActive => status.toLowerCase() == 'active';
  String get cleanEpc => epc.trim().toUpperCase();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'epc': cleanEpc,
      'card_type': cardType,
      'status': status,
      'issued_at': issuedAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
    };
  }

  factory RfidCardRecord.fromMap(Map<String, dynamic> map) {
    return RfidCardRecord(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      epc: map['epc'] as String,
      cardType: map['card_type'] as String? ?? 'student',
      status: map['status'] as String? ?? 'active',
      issuedAt: DateTime.parse(map['issued_at'] as String),
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
    );
  }
}
