import 'dart:async';
import 'rfid_device_interface.dart';
import 'rfid_models.dart';

class SimulatedRfidDevice implements RfidDeviceInterface {
  @override
  final String deviceName = 'Virtual RFID Simulator (U1-CU-71 Emulation)';

  RfidConnectionState _connectionState = RfidConnectionState.disconnected;
  final StreamController<RfidConnectionState> _stateController =
      StreamController<RfidConnectionState>.broadcast();

  // Active tags in the simulated antenna field
  final List<RfidTag> _simulatedFieldTags = [];

  // Memory bank storage: bank -> (address -> hex)
  final Map<int, Map<int, String>> _mockMemory = {};

  bool _lastBeep = false;
  bool _lastGreenLed = false;
  bool _lastRedLed = false;

  bool get lastBeep => _lastBeep;
  bool get lastGreenLed => _lastGreenLed;
  bool get lastRedLed => _lastRedLed;

  @override
  RfidConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected => _connectionState == RfidConnectionState.connected;

  @override
  Stream<RfidConnectionState> get connectionStateStream => _stateController.stream;

  void _setState(RfidConnectionState state) {
    _connectionState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<bool> connect({int port = 100, int baud = 115200}) async {
    _setState(RfidConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 150));
    _setState(RfidConnectionState.connected);
    await triggerAction(beep: true, greenLed: true, durationMs: 150);
    return true;
  }

  @override
  Future<bool> disconnect() async {
    _simulatedFieldTags.clear();
    _setState(RfidConnectionState.disconnected);
    return true;
  }

  /// Inject tags into the simulated reader's antenna field
  void injectTags(List<String> epcs) {
    _simulatedFieldTags.clear();
    for (final epc in epcs) {
      _simulatedFieldTags.add(RfidTag(
        epc: epc,
        readCount: 1,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Remove all tags from antenna field (simulates removing books/card from reader)
  void clearField() {
    _simulatedFieldTags.clear();
  }

  @override
  Future<List<RfidTag>> inventory() async {
    if (!isConnected) return [];
    // Return a copy of current field tags
    return List<RfidTag>.from(_simulatedFieldTags);
  }

  @override
  Future<String?> readMemory({
    required int bank,
    int address = 0,
    int length = 8,
  }) async {
    if (!isConnected) return null;
    return _mockMemory[bank]?[address] ?? 'E28068940000501234567890';
  }

  @override
  Future<bool> writeMemory({
    required int bank,
    int address = 2,
    required String hexData,
  }) async {
    if (!isConnected) return false;
    _mockMemory.putIfAbsent(bank, () => {})[address] = hexData;
    // Also update or add field tag with this new EPC if bank is EPC
    if (bank == 1) {
      if (_simulatedFieldTags.isNotEmpty) {
        final oldTag = _simulatedFieldTags.first;
        _simulatedFieldTags[0] = RfidTag(
          epc: hexData,
          readCount: oldTag.readCount,
        );
      } else {
        _simulatedFieldTags.add(RfidTag(epc: hexData, readCount: 1));
      }
    }
    await triggerAction(beep: true, greenLed: true, durationMs: 200);
    return true;
  }

  @override
  Future<bool> triggerAction({
    bool beep = true,
    bool greenLed = true,
    bool redLed = false,
    bool yellowLed = false,
    int durationMs = 300,
  }) async {
    if (!isConnected) return false;
    _lastBeep = beep;
    _lastGreenLed = greenLed;
    _lastRedLed = redLed;
    return true;
  }

  @override
  void dispose() {
    disconnect();
    _stateController.close();
  }
}
