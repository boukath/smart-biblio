import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/domain/rfid/windows_port_detector.dart';

void main() {
  group('WindowsPortDetector Tests', () {
    test('detectAvailablePorts always contains USB HID (port 100)', () async {
      final ports = await WindowsPortDetector.detectAvailablePorts();
      expect(ports.any((p) => p.portIndex == 100), isTrue);
    });

    test('getCandidatePortsForAutoConnect includes safe ports and excludes bare COM1', () async {
      final candidates = await WindowsPortDetector.getCandidatePortsForAutoConnect();
      expect(candidates.any((p) => p.portIndex == 100), isTrue);

      for (final c in candidates) {
        // Must be USB, USB-Serial or Fongwah
        expect(c.isFongwahLikely || c.isUsbSerial || c.portIndex == 100, isTrue);
      }
    });

    test('findBestFongwahPort returns a valid port number', () async {
      final best = await WindowsPortDetector.findBestFongwahPort();
      expect(best, isNotNull);
    });
  });
}
