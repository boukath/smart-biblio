import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/audit_log.dart';
import '../models/book.dart';
import '../models/book_copy.dart';
import '../models/fine.dart';
import '../models/loan.dart';
import '../models/member.dart';
import '../models/rfid_card.dart';
import '../models/system_settings.dart';
import 'database_schema.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase({String? inMemoryPath}) async {
    // Initialize FFI for Windows desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    String dbPath;
    if (inMemoryPath != null) {
      dbPath = inMemoryPath;
    } else {
      try {
        final dir = await getApplicationSupportDirectory();
        dbPath = p.join(dir.path, AppConstants.databaseFileName);
      } catch (_) {
        // Fallback for command line or test environments
        dbPath = p.join(Directory.current.path, AppConstants.databaseFileName);
      }
    }

    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onCreate: (db, version) async {
          await _createTables(db);
        },
      ),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute(DatabaseSchema.createMembersTable);
    await db.execute(DatabaseSchema.createRfidCardsTable);
    await db.execute(DatabaseSchema.createBooksTable);
    await db.execute(DatabaseSchema.createBookCopiesTable);
    await db.execute(DatabaseSchema.createLoansTable);
    await db.execute(DatabaseSchema.createFinesTable);
    await db.execute(DatabaseSchema.createAuditLogsTable);
    await db.execute(DatabaseSchema.createSystemSettingsTable);

    for (final indexSql in DatabaseSchema.createIndices) {
      await db.execute(indexSql);
    }
  }

  /// Initialize in-memory database for automated testing
  Future<void> initInMemory() async {
    _db = await _initDatabase(inMemoryPath: inMemoryDatabasePath);
  }

  // ==========================================
  // MEMBERS & RFID CARDS
  // ==========================================

  Future<Member?> findMemberByCardEpc(String epc) async {
    final db = await database;
    final cleanEpc = epc.trim().toUpperCase();

    final cardResults = await db.query(
      'rfid_cards',
      where: 'epc = ? AND status = ?',
      whereArgs: [cleanEpc, 'active'],
      limit: 1,
    );

    if (cardResults.isEmpty) return null;

    final memberId = cardResults.first['member_id'] as String;
    final memberResults = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [memberId],
      limit: 1,
    );

    if (memberResults.isEmpty) return null;

    // Update last_used_at on card
    await db.update(
      'rfid_cards',
      {'last_used_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [cardResults.first['id']],
    );

    return Member.fromMap(memberResults.first);
  }

  Future<Member?> getMemberById(String id) async {
    final db = await database;
    final results = await db.query('members', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Member.fromMap(results.first);
  }

  Future<List<Member>> getAllMembers() async {
    final db = await database;
    final results = await db.query('members', orderBy: 'full_name ASC');
    return results.map((m) => Member.fromMap(m)).toList();
  }

  Future<void> insertMember(Member member) async {
    final db = await database;
    await db.insert('members', member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<RfidCardRecord?> getCardByEpc(String epc) async {
    final db = await database;
    final results = await db.query(
      'rfid_cards',
      where: 'epc = ?',
      whereArgs: [epc.trim().toUpperCase()],
    );
    if (results.isEmpty) return null;
    return RfidCardRecord.fromMap(results.first);
  }

  Future<void> assignCardToMember({
    required String memberId,
    required String epc,
    String cardType = 'student',
  }) async {
    final db = await database;
    final clean = epc.trim().toUpperCase();

    await db.transaction((txn) async {
      // Deactivate any existing active cards for this member
      await txn.update(
        'rfid_cards',
        {'status': 'blocked'},
        where: 'member_id = ? AND status = ?',
        whereArgs: [memberId, 'active'],
      );

      // Insert new card
      final card = RfidCardRecord(
        id: _uuid.v4(),
        memberId: memberId,
        epc: clean,
        cardType: cardType,
        status: 'active',
      );
      await txn.insert('rfid_cards', card.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Audit
      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'timestamp': DateTime.now().toIso8601String(),
        'actor_type': 'admin',
        'actor_id': 'system',
        'action': 'CARD_ASSIGNED',
        'entity_type': 'rfid_card',
        'entity_id': card.id,
        'details': 'Assigned card EPC $clean to member $memberId',
      });
    });
  }

  // ==========================================
  // BOOKS & COPIES
  // ==========================================

  Future<void> insertBook(Book book) async {
    final db = await database;
    await db.insert('books', book.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertBookCopy(BookCopy copy) async {
    final db = await database;
    await db.insert('book_copies', copy.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final results = await db.query('books', orderBy: 'title ASC');
    return results.map((b) => Book.fromMap(b)).toList();
  }

  Future<Book?> getBookById(String id) async {
    final db = await database;
    final results = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Book.fromMap(results.first);
  }

  Future<BookCopy?> findCopyByEpc(String epc) async {
    final db = await database;
    final clean = epc.trim().toUpperCase();
    final results = await db.query(
      'book_copies',
      where: 'rfid_epc = ?',
      whereArgs: [clean],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return BookCopy.fromMap(results.first);
  }

  Future<List<BookCopy>> getCopiesForBook(String bookId) async {
    final db = await database;
    final results = await db.query('book_copies',
        where: 'book_id = ?', whereArgs: [bookId]);
    return results.map((c) => BookCopy.fromMap(c)).toList();
  }

  Future<List<Map<String, dynamic>>> getCopiesByShelf(String shelfLocation) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT c.*, b.title, b.author, b.isbn, b.shelf_location
      FROM book_copies c
      JOIN books b ON c.book_id = b.id
      WHERE b.shelf_location = ?
      ORDER BY b.title ASC
    ''', [shelfLocation]);
    return results;
  }

  Future<void> updateCopyEpc(String copyId, String newEpc) async {
    final db = await database;
    final clean = newEpc.trim().toUpperCase();
    await db.transaction((txn) async {
      await txn.update(
        'book_copies',
        {'rfid_epc': clean},
        where: 'id = ?',
        whereArgs: [copyId],
      );
      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'timestamp': DateTime.now().toIso8601String(),
        'actor_type': 'librarian',
        'actor_id': 'admin',
        'action': 'TAG_WRITTEN',
        'entity_type': 'book_copy',
        'entity_id': copyId,
        'details': 'Encoded and linked new EPC $clean to Copy ID $copyId',
      });
    });
  }

  Future<List<String>> getAllShelfLocations() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT shelf_location FROM books ORDER BY shelf_location ASC',
    );
    return results.map((r) => r['shelf_location'] as String).toList();
  }

  // ==========================================
  // CIRCULATION & TRANSACTIONS
  // ==========================================

  Future<List<Loan>> getActiveLoansForMember(String memberId) async {
    final db = await database;
    final results = await db.query(
      'loans',
      where: 'member_id = ? AND status IN (?, ?, ?)',
      whereArgs: [memberId, 'active', 'due_soon', 'overdue'],
      orderBy: 'due_at ASC',
    );
    return results.map((l) => Loan.fromMap(l)).toList();
  }

  Future<Loan?> getActiveLoanForCopy(String copyId) async {
    final db = await database;
    final results = await db.query(
      'loans',
      where: 'copy_id = ? AND status IN (?, ?, ?)',
      whereArgs: [copyId, 'active', 'due_soon', 'overdue'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Loan.fromMap(results.first);
  }

  /// Atomically borrow a book copy
  Future<Loan> borrowBookCopy({
    required Member member,
    required BookCopy copy,
    int durationDays = 14,
    String source = 'self_service',
  }) async {
    final db = await database;
    final now = DateTime.now();
    final dueAt = now.add(Duration(days: durationDays));
    final transactionNo = 'TXN-${now.millisecondsSinceEpoch.toString().substring(5)}';

    final loan = Loan(
      id: _uuid.v4(),
      transactionNo: transactionNo,
      memberId: member.id,
      copyId: copy.id,
      rfidEpc: copy.rfidEpc,
      borrowedAt: now,
      dueAt: dueAt,
      status: 'active',
      source: source,
    );

    await db.transaction((txn) async {
      // 1. Update copy status to 'borrowed'
      await txn.update(
        'book_copies',
        {'status': 'borrowed'},
        where: 'id = ?',
        whereArgs: [copy.id],
      );

      // 2. Insert loan record
      await txn.insert('loans', loan.toMap());

      // 3. Insert audit log
      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'timestamp': now.toIso8601String(),
        'actor_type': source == 'self_service' ? 'student' : 'admin',
        'actor_id': member.id,
        'action': 'BOOK_BORROWED',
        'entity_type': 'book_copy',
        'entity_id': copy.id,
        'details': 'Loan ${loan.transactionNo} for Copy ${copy.copyBarcode} (EPC: ${copy.rfidEpc}) by ${member.fullName}',
      });
    });

    return loan;
  }

  /// Atomically return a book copy
  Future<Loan> returnBookCopy({
    required Loan activeLoan,
    required String copyId,
    double finePerDay = 50.0,
    String returnActor = 'student',
  }) async {
    final db = await database;
    final now = DateTime.now();

    // Check overdue and calculate fine
    double fineAmount = 0.0;
    String fineStatus = 'none';
    Fine? fineRecord;

    if (now.isAfter(activeLoan.dueAt)) {
      final overdueDays = now.difference(activeLoan.dueAt).inDays + 1;
      fineAmount = overdueDays * finePerDay;
      fineStatus = 'pending';

      fineRecord = Fine(
        id: _uuid.v4(),
        memberId: activeLoan.memberId,
        loanId: activeLoan.id,
        copyId: copyId,
        fineType: 'overdue',
        amount: fineAmount,
        reason: '$overdueDays day(s) overdue fine',
      );
    }

    final updatedLoan = Loan(
      id: activeLoan.id,
      transactionNo: activeLoan.transactionNo,
      memberId: activeLoan.memberId,
      copyId: activeLoan.copyId,
      rfidEpc: activeLoan.rfidEpc,
      borrowedAt: activeLoan.borrowedAt,
      dueAt: activeLoan.dueAt,
      returnedAt: now,
      status: 'returned',
      renewalCount: activeLoan.renewalCount,
      fineAmount: fineAmount,
      fineStatus: fineStatus,
      source: activeLoan.source,
      createdAt: activeLoan.createdAt,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. Mark copy available
      await txn.update(
        'book_copies',
        {'status': 'available'},
        where: 'id = ?',
        whereArgs: [copyId],
      );

      // 2. Update loan record
      await txn.update(
        'loans',
        updatedLoan.toMap(),
        where: 'id = ?',
        whereArgs: [activeLoan.id],
      );

      // 3. Create fine if applicable
      if (fineRecord != null) {
        await txn.insert('fines', fineRecord.toMap());
      }

      // 4. Insert audit log
      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'timestamp': now.toIso8601String(),
        'actor_type': returnActor,
        'actor_id': activeLoan.memberId,
        'action': 'BOOK_RETURNED',
        'entity_type': 'book_copy',
        'entity_id': copyId,
        'details': 'Returned ${activeLoan.transactionNo}. Overdue fine: $fineAmount',
      });
    });

    return updatedLoan;
  }

  // ==========================================
  // SYSTEM SETTINGS & AUDIT LOGS
  // ==========================================

  Future<SystemSettings> getSettings() async {
    final db = await database;
    final results = await db.query('system_settings');
    final map = <String, String>{};
    for (final row in results) {
      map[row['key'] as String] = row['value'] as String;
    }
    return SystemSettings.fromMap(map);
  }

  Future<void> saveSettings(SystemSettings settings) async {
    final db = await database;
    final map = settings.toSettingsMap();
    await db.transaction((txn) async {
      for (final entry in map.entries) {
        await txn.insert(
          'system_settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<AuditLog>> getRecentAuditLogs({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'audit_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((a) => AuditLog.fromMap(a)).toList();
  }

  Future<void> logAudit({
    required String actorType,
    required String actorId,
    required String action,
    required String entityType,
    required String entityId,
    required String details,
  }) async {
    final db = await database;
    final log = AuditLog(
      id: _uuid.v4(),
      actorType: actorType,
      actorId: actorId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
    );
    await db.insert('audit_logs', log.toMap());
  }

  // ==========================================
  // ADMIN DASHBOARD & ADVANCED CIRCULATION
  // ==========================================

  Future<Map<String, int>> getDashboardMetrics() async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();

    int count(List<Map<String, Object?>> res) =>
        res.isEmpty || res.first.values.isEmpty
            ? 0
            : (res.first.values.first as int? ?? 0);

    final booksCount = count(await db.rawQuery('SELECT COUNT(*) FROM books'));
    final copiesCount =
        count(await db.rawQuery('SELECT COUNT(*) FROM book_copies'));
    final availableCount = count(await db.rawQuery(
        "SELECT COUNT(*) FROM book_copies WHERE status = 'available'"));
    final activeLoansCount = count(await db.rawQuery(
        "SELECT COUNT(*) FROM loans WHERE status IN ('active', 'due_soon', 'overdue')"));
    final overdueCount = count(await db.rawQuery(
        "SELECT COUNT(*) FROM loans WHERE (status = 'overdue' OR status = 'active') AND due_at < ?",
        [nowIso]));
    final membersCount =
        count(await db.rawQuery('SELECT COUNT(*) FROM members'));
    final activeCardsCount = count(await db.rawQuery(
        "SELECT COUNT(*) FROM rfid_cards WHERE status = 'active'"));

    return {
      'totalBooks': booksCount,
      'totalCopies': copiesCount,
      'availableCopies': availableCount,
      'activeLoans': activeLoansCount,
      'overdueLoans': overdueCount,
      'totalMembers': membersCount,
      'activeCards': activeCardsCount,
    };
  }

  Future<List<Loan>> getAllLoans({String? statusFilter}) async {
    final db = await database;
    List<Map<String, dynamic>> results;
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      results = await db.query(
        'loans',
        where: 'status = ?',
        whereArgs: [statusFilter],
        orderBy: 'borrowed_at DESC',
      );
    } else {
      results = await db.query('loans', orderBy: 'borrowed_at DESC');
    }
    return results.map((l) => Loan.fromMap(l)).toList();
  }

  Future<List<Fine>> getAllFines() async {
    final db = await database;
    final results = await db.query('fines', orderBy: 'created_at DESC');
    return results.map((f) => Fine.fromMap(f)).toList();
  }

  Future<void> payFine(String fineId) async {
    final db = await database;
    await db.update(
      'fines',
      {
        'status': 'paid',
        'paid_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [fineId],
    );
  }

  Future<void> waiveFine(String fineId) async {
    final db = await database;
    await db.update(
      'fines',
      {'status': 'waived'},
      where: 'id = ?',
      whereArgs: [fineId],
    );
  }

  Future<void> renewLoan(String loanId, int additionalDays) async {
    final db = await database;
    final results = await db.query('loans', where: 'id = ?', whereArgs: [loanId]);
    if (results.isEmpty) return;

    final loan = Loan.fromMap(results.first);
    final newDue = loan.dueAt.add(Duration(days: additionalDays));

    await db.transaction((txn) async {
      await txn.update(
        'loans',
        {
          'due_at': newDue.toIso8601String(),
          'renewal_count': loan.renewalCount + 1,
          'status': 'active',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );

      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'timestamp': DateTime.now().toIso8601String(),
        'actor_type': 'librarian',
        'actor_id': 'admin',
        'action': 'LOAN_RENEWED',
        'entity_type': 'loan',
        'entity_id': loanId,
        'details': 'Renewed loan ${loan.transactionNo} for +$additionalDays days. New due: $newDue',
      });
    });
  }

  Future<void> deleteMember(String id) async {
    final db = await database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  /// Filtered audit log query for compliance and admin oversight
  Future<List<AuditLog>> getFilteredAuditLogs({
    String? action,
    String? searchTerm,
    int limit = 200,
  }) async {
    final db = await database;
    String? whereClause;
    final whereArgs = <dynamic>[];

    final conditions = <String>[];
    if (action != null && action.isNotEmpty && action != 'ALL') {
      conditions.add('action = ?');
      whereArgs.add(action);
    }

    if (searchTerm != null && searchTerm.trim().isNotEmpty) {
      final term = '%${searchTerm.trim()}%';
      conditions.add('(details LIKE ? OR actor_id LIKE ? OR entity_id LIKE ?)');
      whereArgs.addAll([term, term, term]);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }

    final results = await db.query(
      'audit_logs',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((a) => AuditLog.fromMap(a)).toList();
  }

  /// Comprehensive loan report dataset for CSV export and audit analysis
  Future<List<Map<String, dynamic>>> getDetailedLoansReport() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        l.transaction_no,
        l.status AS loan_status,
        l.borrowed_at,
        l.due_at,
        l.returned_at,
        l.renewal_count,
        l.fine_amount,
        l.fine_status,
        m.student_number,
        m.full_name AS student_name,
        m.grade_department,
        b.title AS book_title,
        b.author AS book_author,
        b.isbn,
        b.shelf_location,
        c.copy_barcode,
        c.rfid_epc
      FROM loans l
      JOIN members m ON l.member_id = m.id
      JOIN book_copies c ON l.copy_id = c.id
      JOIN books b ON c.book_id = b.id
      ORDER BY l.borrowed_at DESC
    ''');
    return results;
  }

  /// Full physical copy catalog dataset for inventory CSV export
  Future<List<Map<String, dynamic>>> getCatalogInventoryReport() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        b.title,
        b.author,
        b.isbn,
        b.publisher,
        b.publish_year,
        b.category,
        b.shelf_location,
        c.copy_barcode,
        c.rfid_epc,
        c.status AS copy_status,
        c.condition AS copy_condition
      FROM book_copies c
      JOIN books b ON c.book_id = b.id
      ORDER BY b.title ASC, c.copy_barcode ASC
    ''');
    return results;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

