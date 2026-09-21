import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/domain/rfid/native_fongwah_device.dart';
import 'package:smart_biblio/domain/rfid/rfid_models.dart';

void main() {
  group('Native Fongwah Driver Tests', () {
    test('Loads 64-bit E7umf.dll and initializes gracefully', () {
      final nativeDevice = NativeFongwahRfidDevice();
      // Verifies DLL was found and function symbols were bound
      expect(nativeDevice.isDllLoaded, isTrue);
      expect(nativeDevice.connectionState, equals(RfidConnectionState.disconnected));
      expect(nativeDevice.isConnected, isFalse);
    });

    test('Handles connect attempt gracefully when physical hardware is not attached', () async {
      final nativeDevice = NativeFongwahRfidDevice();
      expect(nativeDevice.isDllLoaded, isTrue);

      // Port 100 is USB. If no physical reader is plugged into USB, uhf_connect returns <= 0
      final result = await nativeDevice.connect(port: 100, baud: 115200);
      // It should return false without crashing or throwing unhandled exception
      if (!result) {
        expect(nativeDevice.isConnected, isFalse);
        expect(nativeDevice.connectionState, equals(RfidConnectionState.disconnected));
      } else {
        // Physical reader is actually plugged in!
        expect(nativeDevice.isConnected, isTrue);
        await nativeDevice.disconnect();
      }
    });
  });
}
