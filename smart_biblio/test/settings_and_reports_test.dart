import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_biblio/core/utils/csv_export_service.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:smart_biblio/data/models/audit_log.dart';
import 'package:smart_biblio/data/models/system_settings.dart';
import 'package:smart_biblio/domain/rfid/rfid_manager.dart';
import 'package:smart_biblio/presentation/screens/admin/admin_settings_and_audit_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Settings, Audit & CSV Export Tests', () {
    late AppDatabase db;
    late RfidManager rfid;

    setUp(() async {
      db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);

      rfid = RfidManager();
      rfid.reset();
      await rfid.setSimulationMode(true);
    });

    tearDown(() async {
      rfid.reset();
      await db.close();
    });

    test('Settings save and load persist custom values', () async {
      final initial = await db.getSettings();
      expect(initial.libraryName, equals('Smart Biblio University Library'));
      expect(initial.loanDurationDays, equals(14));

      final updated = SystemSettings(
        libraryName: 'National Polytechnic Library',
        currency: 'USD',
        loanDurationDays: 21,
        maxLoansPerStudent: 8,
        finePerDay: 100.0,
        gracePeriodDays: 3,
        autoTimeoutSeconds: 60,
        debounceMs: 1500,
        allowReturnOtherMemberBooks: true,
        readerPort: 0,
        readerBaud: 57600,
      );

      await db.saveSettings(updated);

      final loaded = await db.getSettings();
      expect(loaded.libraryName, equals('National Polytechnic Library'));
      expect(loaded.currency, equals('USD'));
      expect(loaded.loanDurationDays, equals(21));
      expect(loaded.maxLoansPerStudent, equals(8));
      expect(loaded.finePerDay, equals(100.0));
      expect(loaded.gracePeriodDays, equals(3));
      expect(loaded.autoTimeoutSeconds, equals(60));
      expect(loaded.debounceMs, equals(1500));
      expect(loaded.allowReturnOtherMemberBooks, isTrue);
      expect(loaded.readerPort, equals(0));
      expect(loaded.readerBaud, equals(57600));
    });

    test('Filtered audit logs query filters by action and search keyword', () async {
      // Seed an extra audit log
      await db.logAudit(
        actorType: 'librarian',
        actorId: 'admin_test',
        action: 'TAG_WRITTEN',
        entityType: 'book_copy',
        entityId: 'copy-01-a',
        details: 'Manually re-encoded tag for Clean Code',
      );

      final allLogs = await db.getFilteredAuditLogs(action: 'ALL');
      expect(allLogs, isNotEmpty);

      final tagLogs = await db.getFilteredAuditLogs(action: 'TAG_WRITTEN');
      expect(tagLogs, isNotEmpty);
      expect(tagLogs.every((l) => l.action == 'TAG_WRITTEN'), isTrue);

      final searchedLogs = await db.getFilteredAuditLogs(searchTerm: 'Clean Code');
      expect(searchedLogs, isNotEmpty);
      expect(searchedLogs.any((l) => l.details.contains('Clean Code')), isTrue);
    });

    test('Detailed report queries produce complete datasets', () async {
      final loansReport = await db.getDetailedLoansReport();
      expect(loansReport, isNotEmpty);
      final firstLoan = loansReport.first;
      expect(firstLoan.containsKey('transaction_no'), isTrue);
      expect(firstLoan.containsKey('student_name'), isTrue);
      expect(firstLoan.containsKey('book_title'), isTrue);
      expect(firstLoan.containsKey('rfid_epc'), isTrue);

      final inventoryReport = await db.getCatalogInventoryReport();
      expect(inventoryReport, isNotEmpty);
      final firstItem = inventoryReport.first;
      expect(firstItem.containsKey('title'), isTrue);
      expect(firstItem.containsKey('author'), isTrue);
      expect(firstItem.containsKey('copy_barcode'), isTrue);
      expect(firstItem.containsKey('rfid_epc'), isTrue);
    });

    test('CsvExportService correctly formats CSV lines and escapes characters', () {
      final sampleLogs = [
        AuditLog(
          id: 'log-1',
          timestamp: DateTime(2026, 9, 21, 12, 0, 0),
          actorType: 'student',
          actorId: 'STU-001',
          action: 'BOOK_BORROWED',
          entityType: 'book_copy',
          entityId: 'BC-001',
          details: 'Loan for "Clean Code, 2nd Ed" created',
        ),
      ];

      final csv = CsvExportService.generateAuditLogCsv(sampleLogs);
      expect(csv, contains('ID,Timestamp,Actor Type,Actor ID,Action,Entity Type,Entity ID,Details'));
      expect(csv, contains('"BOOK_BORROWED"'));
      expect(csv, contains('""Clean Code, 2nd Ed""')); // Doubled internal quotes
    });

    testWidgets('AdminSettingsAndAuditView renders tabs and manages settings & logs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppDatabase>.value(value: db),
            Provider<RfidManager>.value(value: rfid),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminSettingsAndAuditView(),
            ),
          ),
        ),
      );

      // Allow background SQLite FFI isolate tasks to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Verify Tab 0 (Settings)
      expect(find.text('GOVERNANCE & CONFIGURATION'), findsOneWidget);
      expect(find.text('Library Identity & Lending Rules'), findsOneWidget);
      expect(find.text('Hardware & Kiosk Terminal Behavior'), findsOneWidget);
      expect(find.text('SAVE SETTINGS'), findsOneWidget);
      expect(find.text('RESTORE FACTORY DEFAULTS'), findsOneWidget);

      // Tap SAVE SETTINGS and allow async commit
      await tester.tap(find.text('SAVE SETTINGS'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      // Dismiss any active SnackBar timer before switching tabs
      tester.binding.scheduleFrame();
      ScaffoldMessenger.of(tester.element(find.byType(AdminSettingsAndAuditView))).clearSnackBars();
      await tester.pump();

      // Switch to Tab 1 (Audit Trail & CSV Reports)
      await tester.tap(find.text('Audit Trail & CSV Reports'));
      await tester.pumpAndSettle();

      expect(find.text('Data Export Center'), findsOneWidget);
      expect(find.text('EXPORT AUDIT LOGS'), findsOneWidget);
      expect(find.text('EXPORT CIRCULATION (CSV)'), findsOneWidget);
      expect(find.text('EXPORT INVENTORY (CSV)'), findsOneWidget);
    });
  });
}
