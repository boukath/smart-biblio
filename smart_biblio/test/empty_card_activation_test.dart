import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/data/database/app_database.dart';
import 'package:smart_biblio/data/database/seed_data.dart';
import 'package:smart_biblio/data/models/member.dart';
import 'package:smart_biblio/domain/rfid/rfid_manager.dart';
import 'package:smart_biblio/presentation/providers/kiosk_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Empty RFID Card Detection & Encoding Tests', () {
    test('isBlankOrEmptyEpc correctly identifies empty, blank, and zero-filled cards', () {
      expect(RfidManager.isBlankOrEmptyEpc(null), isTrue);
      expect(RfidManager.isBlankOrEmptyEpc(''), isTrue);
      expect(RfidManager.isBlankOrEmptyEpc('   '), isTrue);
      expect(RfidManager.isBlankOrEmptyEpc('000000000000000000000000'), isTrue);
      expect(RfidManager.isBlankOrEmptyEpc('0000 0000 0000 0000 0000 0000'), isTrue);
      expect(RfidManager.isBlankOrEmptyEpc('CARD-EMPTY-0001'), isTrue);
      expect(RfidManager.isBlankOrEmptyEpc('BLANK-TAG-00'), isTrue);

      // Programmed valid EPCs should NOT be identified as empty
      expect(RfidManager.isBlankOrEmptyEpc('E28068940000501234567890'), isFalse);
      expect(RfidManager.isBlankOrEmptyEpc('535455323032363030310000'), isFalse);
    });

    test('formatStudentIdToHexEpc and decodeHexEpcToText work symmetrically', () {
      const studentId = 'STU-2026-0042';
      final hexEpc = RfidManager.formatStudentIdToHexEpc(studentId);

      // Must be standard 24 hex characters (96 bits)
      expect(hexEpc.length, equals(24));
      expect(RegExp(r'^[0-9A-F]{24}$').hasMatch(hexEpc), isTrue);

      // ASCII bytes for 'STU20260042'
      final decoded = RfidManager.decodeHexEpcToText(hexEpc);
      expect(decoded, equals('STU20260042'));
    });

    test('RfidManager activateAndWriteStudentCard programs simulated card and field', () async {
      final rfid = RfidManager();
      await rfid.setSimulationMode(true);
      await rfid.connect();

      // Simulate placing an empty card in the field
      rfid.simulateTagScan(['000000000000000000000000']);
      expect(RfidManager.isBlankOrEmptyEpc('000000000000000000000000'), isTrue);

      // Activate card for new student
      const studentNumber = 'STU-2026-0099';
      final expectedEpc = RfidManager.formatStudentIdToHexEpc(studentNumber);

      final writeOk = await rfid.activateAndWriteStudentCard(studentNumber: studentNumber);
      expect(writeOk, isTrue);

      // Verify simulated memory holds the new EPC
      final readBack = await rfid.readTagMemory(bank: 1, address: 2);
      expect(readBack, equals(expectedEpc));

      rfid.dispose();
    });

    test('End-to-End: Activating empty card and registering student allows kiosk lookup', () async {
      final db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);

      final rfid = RfidManager();
      await rfid.setSimulationMode(true);
      await rfid.connect();

      // Blank card on reader
      const blankEpc = '000000000000000000000000';
      expect(RfidManager.isBlankOrEmptyEpc(blankEpc), isTrue);

      // Admin activates card
      const studentId = 'STU-2026-0088';
      final activatedEpc = RfidManager.formatStudentIdToHexEpc(studentId);
      final writeSuccess = await rfid.activateAndWriteStudentCard(studentNumber: studentId);
      expect(writeSuccess, isTrue);

      // Save member in database with the newly activated card
      const uuid = Uuid();
      final newMember = Member(
        id: uuid.v4(),
        studentNumber: studentId,
        fullName: 'Karim Ziani',
        email: 'karim@univ.edu',
        phone: '0555123456',
        gradeDepartment: 'Computer Science',
        maxLoans: 5,
        status: 'active',
      );
      await db.insertMember(newMember);
      await db.assignCardToMember(
        memberId: newMember.id,
        epc: activatedEpc,
        cardType: 'student',
      );

      // Check card is assigned and can be retrieved
      final memberByCard = await db.findMemberByCardEpc(activatedEpc);
      expect(memberByCard, isNotNull);
      expect(memberByCard!.fullName, equals('Karim Ziani'));
      expect(memberByCard.studentNumber, equals(studentId));

      // Test Kiosk tap with newly activated card
      final kiosk = KioskProvider(db: db, rfid: rfid);
      await kiosk.handleCardTapped(activatedEpc);

      expect(kiosk.currentStudent, isNotNull);
      expect(kiosk.currentStudent!.fullName, equals('Karim Ziani'));
      expect(kiosk.step, equals(KioskStep.studentHome));
      expect(kiosk.cardErrorMessage, isNull);

      kiosk.dispose();
      rfid.dispose();
      await db.close();
    });

    test('Kiosk handles empty/unregistered card tap with clear error message', () async {
      final db = AppDatabase();
      await db.initInMemory();
      await SeedData.populateIfEmpty(db);

      final rfid = RfidManager();
      await rfid.setSimulationMode(true);
      await rfid.connect();

      final kiosk = KioskProvider(db: db, rfid: rfid);

      // Student taps a blank, unactivated card at the kiosk
      await kiosk.handleCardTapped('000000000000000000000000');

      expect(kiosk.currentStudent, isNull);
      expect(kiosk.step, equals(KioskStep.idle));
      expect(kiosk.cardErrorMessage, equals('card_not_activated_kiosk'));

      kiosk.clearCardError();
      expect(kiosk.cardErrorMessage, isNull);

      kiosk.dispose();
      rfid.dispose();
      await db.close();
    });
  });
}
