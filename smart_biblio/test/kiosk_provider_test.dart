import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:smart_biblio/domain/rfid/rfid_manager.dart';
import 'package:smart_biblio/domain/services/circulation_service.dart';
import 'package:smart_biblio/presentation/providers/kiosk_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('KioskProvider Full Lifecycle Tests', () {
    late AppDatabase db;
    late RfidManager rfid;
    late CirculationService circulation;
    late KioskProvider provider;

    setUp(() async {
      db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);

      rfid = RfidManager();
      await rfid.setSimulationMode(true);
      circulation = CirculationService(db: db);
      provider = KioskProvider(
        db: db,
        circulation: circulation,
        rfid: rfid,
      );
    });

    tearDown(() async {
      provider.dispose();
      rfid.reset();
      await db.close();
    });

    test('Initializes in idle step waiting for student card', () {
      expect(provider.step, equals(KioskStep.idle));
      expect(provider.currentStudent, isNull);
      expect(provider.activeStudentLoans, isEmpty);
    });

    test('Card tap recognizes student and transitions to studentHome', () async {
      // Tap Ahmed's card
      const ahmedCardEpc = 'E28068940000501234567890';
      await provider.handleCardTapped(ahmedCardEpc);

      expect(provider.step, equals(KioskStep.studentHome));
      expect(provider.currentStudent, isNotNull);
      expect(provider.currentStudent!.fullName, equals('Ahmed Ben Ali'));
      // In seed data, Ahmed already has 1 active loan (Copy 1 of Clean Code)
      expect(provider.activeStudentLoans.length, equals(1));
    });

    test('Borrow workflow scans tags, validates, and confirms borrow', () async {
      // Tap Sarah's card (0 active loans)
      const sarahCardEpc = 'CARD00000000000000000002';
      await provider.handleCardTapped(sarahCardEpc);
      expect(provider.step, equals(KioskStep.studentHome));

      // Start borrow
      provider.startBorrowWorkflow();
      expect(provider.step, equals(KioskStep.borrowScanning));

      // Simulate placing 2 books on reader: Clean Code Copy 2 & Database Systems Copy 1
      final bookTags = [
        'E28068940000000000000002',
        'E28068940000000000000003',
      ];
      rfid.simulateTagScan(bookTags);

      // Wait a tick for inventory stream
      await Future.delayed(const Duration(milliseconds: 350));

      expect(provider.borrowItems.length, equals(2));
      expect(provider.validBorrowCount, equals(2));

      // Confirm borrow
      await provider.confirmBorrow();

      expect(provider.step, equals(KioskStep.successReceipt));
      expect(provider.lastProcessedLoans.length, equals(2));
      expect(provider.activeStudentLoans.length, equals(2));
    });

    test('Return workflow scans borrowed book, validates, and confirms return', () async {
      // Tap Ahmed's card (Ahmed has Clean Code Copy 1 borrowed)
      const ahmedCardEpc = 'E28068940000501234567890';
      await provider.handleCardTapped(ahmedCardEpc);
      expect(provider.step, equals(KioskStep.studentHome));

      // Start return
      provider.startReturnWorkflow();
      expect(provider.step, equals(KioskStep.returnScanning));

      // Simulate placing Ahmed's borrowed book on reader
      rfid.simulateTagScan(['E28068940000000000000001']);
      await Future.delayed(const Duration(milliseconds: 350));

      expect(provider.returnItems.length, equals(1));
      expect(provider.validReturnCount, equals(1));
      expect(provider.returnItems.first.isValid, isTrue);

      // Confirm return
      await provider.confirmReturn();

      expect(provider.step, equals(KioskStep.successReceipt));
      expect(provider.lastProcessedLoans.length, equals(1));
      expect(provider.lastProcessedLoans.first.isReturned, isTrue);
      // Active loans should now be 0
      expect(provider.activeStudentLoans.length, equals(0));
    });

    test('Exit session returns to idle step', () async {
      await provider.handleCardTapped('E28068940000501234567890');
      expect(provider.step, equals(KioskStep.studentHome));

      provider.exitSession();
      expect(provider.step, equals(KioskStep.idle));
      expect(provider.currentStudent, isNull);
    });
  });
}
