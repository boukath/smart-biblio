import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/core/utils/tag_debouncer.dart';
import 'package:smart_biblio/domain/rfid/rfid_models.dart';
import 'package:smart_biblio/domain/rfid/simulated_rfid_device.dart';

void main() {
  group('TagDebouncer Tests', () {
    test('Debounces duplicate tag reads within debounce window', () {
      final debouncer = TagDebouncer(debounceWindow: const Duration(milliseconds: 300));
      const epc = 'E28068940000501234567890';

      // First read: should process
      expect(debouncer.shouldProcess(epc), isTrue);

      // Immediate second read: should NOT process
      expect(debouncer.shouldProcess(epc), isFalse);
      expect(debouncer.getReadCount(epc), equals(2));

      // Different tag: should process
      expect(debouncer.shouldProcess('OTHER_TAG_123'), isTrue);

      // After clearing tag: should process again immediately
      debouncer.clearTag(epc);
      expect(debouncer.shouldProcess(epc), isTrue);
    });
  });

  group('Simulated RFID Device Tests', () {
    test('Device connects and disconnects properly', () async {
      final device = SimulatedRfidDevice();
      expect(device.isConnected, isFalse);

      final connected = await device.connect();
      expect(connected, isTrue);
      expect(device.isConnected, isTrue);
      expect(device.connectionState, equals(RfidConnectionState.connected));

      final disconnected = await device.disconnect();
      expect(disconnected, isTrue);
      expect(device.isConnected, isFalse);
    });

    test('Inventory detects injected tags', () async {
      final device = SimulatedRfidDevice();
      await device.connect();

      final initialTags = await device.inventory();
      expect(initialTags, isEmpty);

      // Inject 3 tags
      final injectedEpcs = [
        'E28068940000000000000001',
        'E28068940000000000000002',
        'E28068940000000000000003',
      ];
      device.injectTags(injectedEpcs);

      final scannedTags = await device.inventory();
      expect(scannedTags.length, equals(3));
      expect(scannedTags.map((t) => t.epc).toList(), equals(injectedEpcs));

      // Clear field
      device.clearField();
      final afterClear = await device.inventory();
      expect(afterClear, isEmpty);

      await device.disconnect();
    });

    test('Write memory updates simulated tag and triggers action', () async {
      final device = SimulatedRfidDevice();
      await device.connect();

      device.injectTags(['OLD_EPC_1111']);
      final writeSuccess = await device.writeMemory(
        bank: 1,
        address: 2,
        hexData: 'NEW_EPC_9999',
      );

      expect(writeSuccess, isTrue);
      final tags = await device.inventory();
      expect(tags.first.epc, equals('NEW_EPC_9999'));
      expect(device.lastBeep, isTrue);
      expect(device.lastGreenLed, isTrue);

      await device.disconnect();
    });
  });
}
