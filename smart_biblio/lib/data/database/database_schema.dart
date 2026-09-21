class DatabaseSchema {
  static const int version = 1;

  static const String createMembersTable = '''
    CREATE TABLE IF NOT EXISTS members (
      id TEXT PRIMARY KEY,
      student_number TEXT UNIQUE NOT NULL,
      full_name TEXT NOT NULL,
      email TEXT,
      phone TEXT,
      grade_department TEXT,
      max_loans INTEGER NOT NULL DEFAULT 5,
      status TEXT NOT NULL DEFAULT 'active',
      avatar_url TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createRfidCardsTable = '''
    CREATE TABLE IF NOT EXISTS rfid_cards (
      id TEXT PRIMARY KEY,
      member_id TEXT NOT NULL,
      epc TEXT UNIQUE NOT NULL,
      card_type TEXT NOT NULL DEFAULT 'student',
      status TEXT NOT NULL DEFAULT 'active',
      issued_at TEXT NOT NULL,
      last_used_at TEXT,
      FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE
    );
  ''';

  static const String createBooksTable = '''
    CREATE TABLE IF NOT EXISTS books (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      isbn TEXT NOT NULL,
      publisher TEXT,
      publish_year INTEGER,
      category TEXT NOT NULL DEFAULT 'General',
      shelf_location TEXT NOT NULL DEFAULT 'A-01',
      description TEXT,
      cover_url TEXT,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createBookCopiesTable = '''
    CREATE TABLE IF NOT EXISTS book_copies (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      copy_barcode TEXT UNIQUE NOT NULL,
      rfid_epc TEXT UNIQUE NOT NULL,
      status TEXT NOT NULL DEFAULT 'available',
      condition TEXT NOT NULL DEFAULT 'good',
      created_at TEXT NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    );
  ''';

  static const String createLoansTable = '''
    CREATE TABLE IF NOT EXISTS loans (
      id TEXT PRIMARY KEY,
      transaction_no TEXT UNIQUE NOT NULL,
      member_id TEXT NOT NULL,
      copy_id TEXT NOT NULL,
      rfid_epc TEXT NOT NULL,
      borrowed_at TEXT NOT NULL,
      due_at TEXT NOT NULL,
      returned_at TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      renewal_count INTEGER NOT NULL DEFAULT 0,
      fine_amount REAL NOT NULL DEFAULT 0.0,
      fine_status TEXT NOT NULL DEFAULT 'none',
      source TEXT NOT NULL DEFAULT 'self_service',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (member_id) REFERENCES members (id),
      FOREIGN KEY (copy_id) REFERENCES book_copies (id)
    );
  ''';

  static const String createFinesTable = '''
    CREATE TABLE IF NOT EXISTS fines (
      id TEXT PRIMARY KEY,
      member_id TEXT NOT NULL,
      loan_id TEXT NOT NULL,
      copy_id TEXT NOT NULL,
      fine_type TEXT NOT NULL,
      amount REAL NOT NULL,
      currency TEXT NOT NULL DEFAULT 'DZD',
      status TEXT NOT NULL DEFAULT 'pending',
      reason TEXT,
      created_at TEXT NOT NULL,
      paid_at TEXT,
      FOREIGN KEY (member_id) REFERENCES members (id),
      FOREIGN KEY (loan_id) REFERENCES loans (id),
      FOREIGN KEY (copy_id) REFERENCES book_copies (id)
    );
  ''';

  static const String createAuditLogsTable = '''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      timestamp TEXT NOT NULL,
      actor_type TEXT NOT NULL,
      actor_id TEXT NOT NULL,
      action TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      details TEXT NOT NULL
    );
  ''';

  static const String createSystemSettingsTable = '''
    CREATE TABLE IF NOT EXISTS system_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''';

  static const List<String> createIndices = [
    'CREATE INDEX IF NOT EXISTS idx_rfid_cards_epc ON rfid_cards(epc);',
    'CREATE INDEX IF NOT EXISTS idx_rfid_cards_member ON rfid_cards(member_id);',
    'CREATE INDEX IF NOT EXISTS idx_book_copies_epc ON book_copies(rfid_epc);',
    'CREATE INDEX IF NOT EXISTS idx_book_copies_book ON book_copies(book_id);',
    'CREATE INDEX IF NOT EXISTS idx_loans_member ON loans(member_id);',
    'CREATE INDEX IF NOT EXISTS idx_loans_copy ON loans(copy_id);',
    'CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);',
    'CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_logs(timestamp);',
  ];
}
