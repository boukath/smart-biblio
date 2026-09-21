class BookCopy {
  final String id;
  final String bookId;
  final String copyBarcode;
  final String rfidEpc;
  final String status; // 'available', 'borrowed', 'reserved', 'maintenance', 'lost'
  final String condition; // 'excellent', 'good', 'fair', 'damaged'
  final DateTime createdAt;

  BookCopy({
    required this.id,
    required this.bookId,
    required this.copyBarcode,
    required this.rfidEpc,
    this.status = 'available',
    this.condition = 'good',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAvailable => status.toLowerCase() == 'available';
  bool get isBorrowed => status.toLowerCase() == 'borrowed';
  String get cleanEpc => rfidEpc.trim().toUpperCase();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'copy_barcode': copyBarcode,
      'rfid_epc': cleanEpc,
      'status': status,
      'condition': condition,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BookCopy.fromMap(Map<String, dynamic> map) {
    return BookCopy(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      copyBarcode: map['copy_barcode'] as String,
      rfidEpc: map['rfid_epc'] as String,
      status: map['status'] as String? ?? 'available',
      condition: map['condition'] as String? ?? 'good',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
