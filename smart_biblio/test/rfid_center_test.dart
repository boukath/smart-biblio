import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:smart_biblio/data/models/book_copy.dart';
import 'package:smart_biblio/domain/rfid/rfid_manager.dart';
import 'package:smart_biblio/presentation/screens/admin/admin_rfid_center_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('RFID Center & Shelf Audit Tests', () {
    late AppDatabase db;
    late RfidManager rfid;

    setUp(() async {
      db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);

      rfid = RfidManager();
      rfid.reset();
      await rfid.setSimulationMode(true);
      await rfid.connect();
    });

    tearDown(() async {
      rfid.reset();
      await db.close();
    });

    test('Shelf queries retrieve copies and unique shelf locations', () async {
      final shelves = await db.getAllShelfLocations();
      expect(shelves, isNotEmpty);
      expect(shelves, contains('CS-101'));
      expect(shelves, contains('CS-102'));

      final csCopies = await db.getCopiesByShelf('CS-101');
      expect(csCopies.length, equals(2)); // Clean Code copies 1 & 2
      expect(csCopies.any((c) => c['copy_barcode'] == 'BC-CC-001'), isTrue);
      expect(csCopies.any((c) => c['copy_barcode'] == 'BC-CC-002'), isTrue);
    });

    test('updateCopyEpc updates tag EPC in database', () async {
      final copy = (await db.findCopyByEpc('E28068940000000000000001'))!;
      expect(copy.copyBarcode, equals('BC-CC-001'));

      const newEpc = 'E28068940000999999999999';
      await db.updateCopyEpc(copy.id, newEpc);

      // Verify old EPC no longer matches
      final oldCheck = await db.findCopyByEpc('E28068940000000000000001');
      expect(oldCheck, isNull);

      // Verify new EPC matches the same copy
      final newCheck = await db.findCopyByEpc(newEpc);
      expect(newCheck, isNotNull);
      expect(newCheck!.id, equals(copy.id));
      expect(newCheck.copyBarcode, equals('BC-CC-001'));
    });

    test('Shelf audit classification accurately detects Present, Missing, Misplaced, and Unknown', () async {
      // Shelf CS-101 expected copies:
      // BC-CC-001: E28068940000000000000001
      // BC-CC-002: E28068940000000000000002
      final expectedCopies = await db.getCopiesByShelf('CS-101');
      final expectedEpcs = expectedCopies.map((c) => c['rfid_epc'] as String).toSet();

      // Scanned EPCs during shelf audit:
      // 1. E28068940000000000000001 (Present on CS-101)
      // 2. E28068940000000000000003 (Misplaced! This is BC-DB-001 which belongs to CS-102)
      // 3. E28068940000FFFFFFFFFFFF (Unknown! Not in catalog at all)
      final scannedEpcs = <String>{
        'E28068940000000000000001',
        'E28068940000000000000003',
        'E28068940000FFFFFFFFFFFF',
      };

      // Classification logic
      final present = <Map<String, dynamic>>[];
      final missing = <Map<String, dynamic>>[];
      final misplaced = <BookCopy>[];
      final unknown = <String>[];

      // Check expected
      for (final copy in expectedCopies) {
        if (scannedEpcs.contains(copy['rfid_epc'])) {
          present.add(copy);
        } else {
          missing.add(copy);
        }
      }

      // Check unexpected detected
      final unexpectedScanned = scannedEpcs.difference(expectedEpcs);
      for (final epc in unexpectedScanned) {
        final alienCopy = await db.findCopyByEpc(epc);
        if (alienCopy != null) {
          misplaced.add(alienCopy);
        } else {
          unknown.add(epc);
        }
      }

      // Assertions
      expect(present.length, equals(1));
      expect(present.first['copy_barcode'], equals('BC-CC-001'));

      expect(missing.length, equals(1));
      expect(missing.first['copy_barcode'], equals('BC-CC-002'));

      expect(misplaced.length, equals(1));
      expect(misplaced.first.copyBarcode, equals('BC-DB-001'));
      final alienBook = await db.getBookById(misplaced.first.bookId);
      expect(alienBook?.shelfLocation, equals('CS-102'));

      expect(unknown.length, equals(1));
      expect(unknown.first, equals('E28068940000FFFFFFFFFFFF'));
    });

    test('RfidManager writes EPC and reads tag memory in simulated mode', () async {
      const targetEpc = 'E28068940000112233445566';
      final writeOk = await rfid.writeEpc(targetEpc);
      expect(writeOk, isTrue);

      final readMemory = await rfid.device.readMemory(bank: 1, address: 2, length: 6);
      expect(readMemory, isNotNull);
      expect(readMemory, isNotEmpty);

      // Buzzer and LED action trigger
      final actionOk = await rfid.device.triggerAction(beep: true, greenLed: true, durationMs: 100);
      expect(actionOk, isTrue);
    });

    testWidgets('AdminRfidCenterView renders all 3 tabs properly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppDatabase>.value(value: db),
            Provider<RfidManager>.value(value: rfid),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminRfidCenterView(),
            ),
          ),
        ),
      );

      // Let initial async load settle
      await tester.pump(const Duration(milliseconds: 300));

      // Tab 0: Reader Diagnostics & Hardware
      expect(find.text('FONGWAH U1-CU-71 HARDWARE CENTER'), findsOneWidget);
      expect(find.text('Hardware Connection & Port Configuration'), findsOneWidget);
      expect(find.text('Raw Memory Bank Inspector'), findsOneWidget);
      expect(find.text('READ MEMORY'), findsOneWidget);

      // Switch to Tab 1: Tag Writer & Encoder
      await tester.tap(find.text('Tag Writer & Encoder'));
      await tester.pumpAndSettle();
      expect(find.text('Encode & Write Physical RFID Tags'), findsOneWidget);
      expect(find.text('Batch Mode'), findsOneWidget);
      expect(find.text('WRITE & VERIFY TAG'), findsOneWidget);

      // Switch to Tab 2: Shelf Inventory Audit
      await tester.tap(find.text('Shelf Inventory Audit'));
      await tester.pumpAndSettle();
      expect(find.text('START SHELF SCAN'), findsOneWidget);
      expect(find.textContaining('Expected'), findsOneWidget);
      expect(find.textContaining('Present'), findsOneWidget);
      expect(find.textContaining('Missing'), findsOneWidget);
      expect(find.textContaining('Misplaced'), findsOneWidget);
    });
  });
}
