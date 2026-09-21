class Member {
  final String id;
  final String studentNumber;
  final String fullName;
  final String email;
  final String phone;
  final String gradeDepartment;
  final int maxLoans;
  final String status; // 'active', 'suspended', 'expired'
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Member({
    required this.id,
    required this.studentNumber,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.gradeDepartment,
    this.maxLoans = 5,
    this.status = 'active',
    this.avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => status.toLowerCase() == 'active';
  bool get isSuspended => status.toLowerCase() == 'suspended';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_number': studentNumber,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'grade_department': gradeDepartment,
      'max_loans': maxLoans,
      'status': status,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      studentNumber: map['student_number'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      gradeDepartment: map['grade_department'] as String? ?? '',
      maxLoans: map['max_loans'] as int? ?? 5,
      status: map['status'] as String? ?? 'active',
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
