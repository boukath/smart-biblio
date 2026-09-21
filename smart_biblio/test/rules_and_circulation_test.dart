import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:smart_biblio/domain/services/circulation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Circulation & Rules Engine Tests', () {
    late AppDatabase db;
    late CirculationService circulationService;

    setUp(() async {
      db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);
      circulationService = CirculationService(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Validates borrow tags correctly: available, already borrowed, unknown tag', () async {
      // Sarah Chen (active student, 0 active loans)
      final sarah = (await db.getAllMembers())[1];

      // Available: Copy 2 of Clean Code (E28068940000000000000002)
      // Already borrowed: Copy 1 of Clean Code (E28068940000000000000001) - borrowed by Ahmed in seed data
      // Unknown RFID: RANDOM_UNREGISTERED_TAG
      final scanBatch = [
        'E28068940000000000000002',
        'E28068940000000000000001',
        'RANDOM_UNREGISTERED_TAG',
      ];

      final results = await circulationService.validateBorrowTags(
        member: sarah,
        epcs: scanBatch,
      );

      expect(results.length, equals(3));

      // 1. Available book
      expect(results[0].isValid, isTrue);
      expect(results[0].book?.title, contains('Clean Code'));

      // 2. Already borrowed book
      expect(results[1].isValid, isFalse);
      expect(results[1].reason, contains('BORROWED'));

      // 3. Unknown tag
      expect(results[2].isValid, isFalse);
      expect(results[2].reason, contains('Unknown RFID tag'));
    });

    test('Suspended student cannot borrow books', () async {
      // Yasmine Kaci (status: suspended)
      final yasmine = (await db.getAllMembers())[3];
      expect(yasmine.status, equals('suspended'));

      final scanBatch = ['E28068940000000000000002'];
      final results = await circulationService.validateBorrowTags(
        member: yasmine,
        epcs: scanBatch,
      );

      expect(results.first.isValid, isFalse);
      expect(results.first.reason, contains('SUSPENDED'));
    });

    test('Validates return tags and calculates overdue fine', () async {
      // Ahmed Ben Ali has Copy 1 of Clean Code borrowed in seed data
      final ahmed = (await db.getAllMembers())[0];
      const copy1Epc = 'E28068940000000000000001';

      // 1. Return within due date
      final normalReturn = await circulationService.validateReturnTags(
        member: ahmed,
        epcs: [copy1Epc],
      );
      expect(normalReturn.first.isValid, isTrue);
      expect(normalReturn.first.isOverdue, isFalse);
      expect(normalReturn.first.fineAmount, equals(0.0));

      // 2. Return 5 days overdue (simulated checkTime = now + 19 days, loan is 14 days)
      final simulatedFutureDate = DateTime.now().add(const Duration(days: 19));
      final overdueReturn = await circulationService.validateReturnTags(
        member: ahmed,
        epcs: [copy1Epc],
        checkTime: simulatedFutureDate,
      );
      expect(overdueReturn.first.isValid, isTrue);
      expect(overdueReturn.first.isOverdue, isTrue);
      expect(overdueReturn.first.overdueDays, greaterThanOrEqualTo(5));
      expect(overdueReturn.first.fineAmount, greaterThan(0.0));
    });

    test('Prevents returning another student\'s book when policy is strict', () async {
      // Sarah attempts to return Ahmed's book (Copy 1 of Clean Code)
      final sarah = (await db.getAllMembers())[1];
      const ahmedBorrowedCopyEpc = 'E28068940000000000000001';

      final results = await circulationService.validateReturnTags(
        member: sarah,
        epcs: [ahmedBorrowedCopyEpc],
      );

      expect(results.first.isValid, isFalse);
      expect(results.first.belongsToCurrentStudent, isFalse);
      expect(results.first.reason, contains('Ahmed Ben Ali'));
    });

    test('End-to-end commitBorrow and commitReturn', () async {
      final sarah = (await db.getAllMembers())[1];
      const copyEpc = 'E28068940000000000000004'; // Operating Systems copy

      // Validate borrow
      final borrowItems = await circulationService.validateBorrowTags(
        member: sarah,
        epcs: [copyEpc],
      );
      expect(borrowItems.first.isValid, isTrue);

      // Commit borrow
      final loans = await circulationService.commitBorrow(
        member: sarah,
        items: borrowItems,
      );
      expect(loans.length, equals(1));
      expect(loans.first.status, equals('active'));

      // Validate return
      final returnItems = await circulationService.validateReturnTags(
        member: sarah,
        epcs: [copyEpc],
      );
      expect(returnItems.first.isValid, isTrue);

      // Commit return
      final returned = await circulationService.commitReturn(
        member: sarah,
        items: returnItems,
      );
      expect(returned.length, equals(1));
      expect(returned.first.status, equals('returned'));
    });
  });
}
