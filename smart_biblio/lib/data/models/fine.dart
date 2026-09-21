class Fine {
  final String id;
  final String memberId;
  final String loanId;
  final String copyId;
  final String fineType; // 'overdue', 'lost_book', 'damaged_book', 'replacement'
  final double amount;
  final String currency;
  final String status; // 'pending', 'paid', 'waived'
  final String reason;
  final DateTime createdAt;
  final DateTime? paidAt;

  Fine({
    required this.id,
    required this.memberId,
    required this.loanId,
    required this.copyId,
    required this.fineType,
    required this.amount,
    this.currency = 'DZD',
    this.status = 'pending',
    this.reason = 'Overdue loan fine',
    DateTime? createdAt,
    this.paidAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isWaived => status.toLowerCase() == 'waived';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'loan_id': loanId,
      'copy_id': copyId,
      'fine_type': fineType,
      'amount': amount,
      'currency': currency,
      'status': status,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
    };
  }

  factory Fine.fromMap(Map<String, dynamic> map) {
    return Fine(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      loanId: map['loan_id'] as String,
      copyId: map['copy_id'] as String,
      fineType: map['fine_type'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'DZD',
      status: map['status'] as String? ?? 'pending',
      reason: map['reason'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at'] as String) : null,
    );
  }
}
