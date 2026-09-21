import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:smart_biblio/data/models/book.dart';
import 'package:smart_biblio/data/models/book_copy.dart';
import 'package:smart_biblio/data/models/fine.dart';
import 'package:smart_biblio/data/models/member.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Admin Features & Backoffice Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getDashboardMetrics aggregates accurate counts', () async {
      final metrics = await db.getDashboardMetrics();

      expect(metrics['totalBooks'], equals(6));
      expect(metrics['totalCopies'], equals(6));
      expect(metrics['availableCopies'], equals(5));
      expect(metrics['activeLoans'], equals(1)); // Ahmed's loan from seed
      expect(metrics['totalMembers'], equals(4));
      expect(metrics['activeCards'], equals(4));
    });

    test('Admin can create book with physical copies and delete book', () async {
      const uuid = Uuid();
      final newBook = Book(
        id: 'book-new-test',
        title: 'Modern Compiler Implementation in Java',
        author: 'Andrew W. Appel',
        isbn: '978-0521820608',
        category: 'Computer Science',
      );

      await db.insertBook(newBook);
      final copy = BookCopy(
        id: uuid.v4(),
        bookId: newBook.id,
        copyBarcode: 'BC-TEST-001',
        rfidEpc: 'E28068940000TEST00000001',
      );
      await db.insertBookCopy(copy);

      final fetched = await db.getBookById(newBook.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Modern Compiler Implementation in Java'));

      final copies = await db.getCopiesForBook(newBook.id);
      expect(copies.length, equals(1));
      expect(copies.first.copyBarcode, equals('BC-TEST-001'));

      // Delete book
      await db.deleteBook(newBook.id);
      expect(await db.getBookById(newBook.id), isNull);
    });

    test('Admin can register member and assign new RFID card', () async {
      const uuid = Uuid();
      final newMember = Member(
        id: uuid.v4(),
        studentNumber: 'STU-2026-999',
        fullName: 'Leila Mansouri',
        email: 'leila.m@univ.edu',
        phone: '+213 555 777 999',
        gradeDepartment: 'Software Engineering',
      );

      await db.insertMember(newMember);

      // Assign RFID card
      const newCardEpc = 'CARD99999999999999999999';
      await db.assignCardToMember(
        memberId: newMember.id,
        epc: newCardEpc,
      );

      // Verify member is found via new card
      final found = await db.findMemberByCardEpc(newCardEpc);
      expect(found, isNotNull);
      expect(found!.fullName, equals('Leila Mansouri'));

      // Re-assign new card (simulating lost card replacement)
      const replacementCardEpc = 'CARD88888888888888888888';
      await db.assignCardToMember(
        memberId: newMember.id,
        epc: replacementCardEpc,
      );

      // Old card should now be blocked
      final oldFound = await db.findMemberByCardEpc(newCardEpc);
      expect(oldFound, isNull);

      // New replacement card is active
      final replacementFound = await db.findMemberByCardEpc(replacementCardEpc);
      expect(replacementFound, isNotNull);
    });

    test('Admin can renew loans and manage fines (pay/waive)', () async {
      // Find Ahmed's active loan from seed data
      final loans = await db.getAllLoans();
      expect(loans.isNotEmpty, isTrue);

      final activeLoan = loans.first;
      final originalDue = activeLoan.dueAt;

      // Renew loan +14 days
      await db.renewLoan(activeLoan.id, 14);

      final updatedLoans = await db.getAllLoans();
      final renewedLoan = updatedLoans.firstWhere((l) => l.id == activeLoan.id);

      expect(renewedLoan.renewalCount, equals(activeLoan.renewalCount + 1));
      expect(
        renewedLoan.dueAt.difference(originalDue).inDays,
        equals(14),
      );

      // Create a test fine and test Pay & Waive
      const uuid = Uuid();
      final fine = Fine(
        id: uuid.v4(),
        memberId: activeLoan.memberId,
        loanId: activeLoan.id,
        copyId: activeLoan.copyId,
        fineType: 'overdue',
        amount: 250.0,
      );
      final rawDb = await db.database;
      await rawDb.insert('fines', fine.toMap());

      var allFines = await db.getAllFines();
      expect(allFines.any((f) => f.id == fine.id && f.isPending), isTrue);

      // Mark fine as paid
      await db.payFine(fine.id);
      allFines = await db.getAllFines();
      expect(allFines.firstWhere((f) => f.id == fine.id).isPaid, isTrue);

      // Waive fine
      await db.waiveFine(fine.id);
      allFines = await db.getAllFines();
      expect(allFines.firstWhere((f) => f.id == fine.id).isWaived, isTrue);
    });
  });
}
