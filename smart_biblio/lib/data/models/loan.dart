class Loan {
  final String id;
  final String transactionNo;
  final String memberId;
  final String copyId;
  final String rfidEpc;
  final DateTime borrowedAt;
  final DateTime dueAt;
  final DateTime? returnedAt;
  final String status; // 'active', 'due_soon', 'overdue', 'returned', 'lost'
  final int renewalCount;
  final double fineAmount;
  final String fineStatus; // 'none', 'pending', 'paid', 'waived'
  final String source; // 'self_service', 'librarian', 'admin'
  final DateTime createdAt;
  final DateTime updatedAt;

  Loan({
    required this.id,
    required this.transactionNo,
    required this.memberId,
    required this.copyId,
    required this.rfidEpc,
    required this.borrowedAt,
    required this.dueAt,
    this.returnedAt,
    this.status = 'active',
    this.renewalCount = 0,
    this.fineAmount = 0.0,
    this.fineStatus = 'none',
    this.source = 'self_service',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isReturned => status.toLowerCase() == 'returned';
  bool get isActive => status.toLowerCase() == 'active' || status.toLowerCase() == 'due_soon' || status.toLowerCase() == 'overdue';
  bool get isOverdue => DateTime.now().isAfter(dueAt) && !isReturned;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_no': transactionNo,
      'member_id': memberId,
      'copy_id': copyId,
      'rfid_epc': rfidEpc.trim().toUpperCase(),
      'borrowed_at': borrowedAt.toIso8601String(),
      'due_at': dueAt.toIso8601String(),
      'returned_at': returnedAt?.toIso8601String(),
      'status': status,
      'renewal_count': renewalCount,
      'fine_amount': fineAmount,
      'fine_status': fineStatus,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as String,
      transactionNo: map['transaction_no'] as String,
      memberId: map['member_id'] as String,
      copyId: map['copy_id'] as String,
      rfidEpc: map['rfid_epc'] as String,
      borrowedAt: DateTime.parse(map['borrowed_at'] as String),
      dueAt: DateTime.parse(map['due_at'] as String),
      returnedAt: map['returned_at'] != null
          ? DateTime.parse(map['returned_at'] as String)
          : null,
      status: map['status'] as String? ?? 'active',
      renewalCount: map['renewal_count'] as int? ?? 0,
      fineAmount: (map['fine_amount'] as num?)?.toDouble() ?? 0.0,
      fineStatus: map['fine_status'] as String? ?? 'none',
      source: map['source'] as String? ?? 'self_service',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
