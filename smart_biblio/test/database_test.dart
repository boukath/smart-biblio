import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database & Seed Data Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Seeds members and finds student by RFID card EPC', () async {
      final members = await db.getAllMembers();
      expect(members.length, equals(4));

      // Ahmed's card
      const ahmedCardEpc = 'E28068940000501234567890';
      final found = await db.findMemberByCardEpc(ahmedCardEpc);
      expect(found, isNotNull);
      expect(found!.fullName, equals('Ahmed Ben Ali'));
      expect(found.studentNumber, equals('STU-2026-001'));
      expect(found.isActive, isTrue);

      // Unknown card
      final unknown = await db.findMemberByCardEpc('UNKNOWN_CARD_999');
      expect(unknown, isNull);
    });

    test('Seeds books, copies and finds copy by RFID EPC', () async {
      final books = await db.getAllBooks();
      expect(books.length, equals(6));

      const cleanCodeEpc = 'E28068940000000000000001';
      final copy = await db.findCopyByEpc(cleanCodeEpc);
      expect(copy, isNotNull);
      expect(copy!.copyBarcode, equals('BC-CC-001'));
      expect(copy.bookId, equals('book-01'));
    });

    test('Borrow and return workflow operates atomically with audit log', () async {
      final member = (await db.getAllMembers())[1]; // Sarah Chen
      const bookEpc = 'E28068940000000000000003'; // Database Systems copy
      final copy = (await db.findCopyByEpc(bookEpc))!;
      expect(copy.status, equals('available'));

      // 1. Borrow copy
      final loan = await db.borrowBookCopy(
        member: member,
        copy: copy,
        durationDays: 14,
      );

      expect(loan.status, equals('active'));
      expect(loan.memberId, equals(member.id));

      // Verify copy is now marked borrowed
      final borrowedCopy = (await db.findCopyByEpc(bookEpc))!;
      expect(borrowedCopy.status, equals('borrowed'));

      // 2. Return copy
      final returnedLoan = await db.returnBookCopy(
        activeLoan: loan,
        copyId: copy.id,
      );

      expect(returnedLoan.status, equals('returned'));
      expect(returnedLoan.returnedAt, isNotNull);

      // Verify copy is available again
      final returnedCopy = (await db.findCopyByEpc(bookEpc))!;
      expect(returnedCopy.status, equals('available'));

      // 3. Audit log verification
      final auditLogs = await db.getRecentAuditLogs();
      expect(auditLogs.any((a) => a.action == 'BOOK_BORROWED'), isTrue);
      expect(auditLogs.any((a) => a.action == 'BOOK_RETURNED'), isTrue);
    });
  });
}
