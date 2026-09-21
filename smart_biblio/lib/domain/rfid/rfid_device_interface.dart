import 'rfid_models.dart';

abstract class RfidDeviceInterface {
  /// Name and descriptor of this device implementation
  String get deviceName;

  /// Current connection state
  RfidConnectionState get connectionState;

  /// Whether the reader is physically or virtually connected
  bool get isConnected;

  /// Stream of connection state changes
  Stream<RfidConnectionState> get connectionStateStream;

  /// Connect to the RFID reader (port 100 for USB, or COM index 0, 1, 2...)
  Future<bool> connect({int port = 100, int baud = 115200});

  /// Disconnect reader
  Future<bool> disconnect();

  /// Perform inventory of all UHF tags currently in the antenna field.
  /// Returns a list of detected unique tags with their read counts.
  Future<List<RfidTag>> inventory();

  /// Read memory bank from tag (1=EPC, 2=TID, 3=USER, 0=Reserved)
  Future<String?> readMemory({
    required int bank,
    int address = 0,
    int length = 8,
  });

  /// Write memory bank to tag
  Future<bool> writeMemory({
    required int bank,
    int address = 2,
    required String hexData,
  });

  /// Trigger buzzer and LED actions
  /// [beep]: Sound buzzer
  /// [greenLed]: Turn on green LED
  /// [redLed]: Turn on red LED
  /// [yellowLed]: Turn on yellow LED
  /// [durationMs]: duration in milliseconds (mapped to 10ms units)
  Future<bool> triggerAction({
    bool beep = true,
    bool greenLed = true,
    bool redLed = false,
    bool yellowLed = false,
    int durationMs = 300,
  });

  /// Clean up resources
  void dispose();
}
