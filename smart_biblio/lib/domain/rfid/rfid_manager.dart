import 'dart:async';
import '../../core/utils/tag_debouncer.dart';
import 'native_fongwah_device.dart';
import 'rfid_device_interface.dart';
import 'rfid_models.dart';
import 'simulated_rfid_device.dart';

class RfidManager {
  static final RfidManager _instance = RfidManager._internal();
  factory RfidManager() => _instance;
  RfidManager._internal() {
    _initDevice();
  }

  late RfidDeviceInterface _device;
  bool _useSimulation = false;
  RfidReaderMode _currentMode = RfidReaderMode.idle;
  Timer? _pollingTimer;

  final TagDebouncer _debouncer = TagDebouncer();

  // Stream Controllers
  final StreamController<String> _cardScanController =
      StreamController<String>.broadcast();
  final StreamController<List<RfidTag>> _inventoryController =
      StreamController<List<RfidTag>>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  // Getters
  RfidDeviceInterface get device => _device;
  bool get isSimulated => _useSimulation;
  RfidReaderMode get currentMode => _currentMode;
  bool get isConnected => _device.isConnected;

  Stream<String> get onCardDetected => _cardScanController.stream;
  Stream<List<RfidTag>> get onTagsInventory => _inventoryController.stream;
  Stream<String> get onLogMessage => _logController.stream;
  Stream<RfidConnectionState> get onConnectionStateChanged =>
      _device.connectionStateStream;

  void _log(String message) {
    if (!_logController.isClosed) {
      _logController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    }
  }

  void _initDevice() {
    if (_useSimulation) {
      _device = SimulatedRfidDevice();
      _log('Initialized Virtual RFID Simulator');
    } else {
      final native = NativeFongwahRfidDevice();
      if (native.isDllLoaded) {
        _device = native;
        _log('Initialized Native Fongwah U1-CU-71 Driver (DLL loaded)');
      } else {
        _useSimulation = true;
        _device = SimulatedRfidDevice();
        _log('DLL not accessible, falling back to Virtual RFID Simulator');
      }
    }
  }

  /// Switch between Native SDK and Virtual Simulator
  Future<void> setSimulationMode(bool enabled) async {
    if (_useSimulation == enabled) return;
    _log('Switching reader mode: simulation = $enabled');
    await disconnect();
    _device.dispose();
    _useSimulation = enabled;
    if (_useSimulation) {
      _device = SimulatedRfidDevice();
    } else {
      _device = NativeFongwahRfidDevice();
    }
    await connect();
  }

  Future<bool> connect({int port = 100, int baud = 115200}) async {
    _log('Connecting to RFID reader (Port: $port, Baud: $baud)...');
    final success = await _device.connect(port: port, baud: baud);
    if (success) {
      _log('Connected successfully to ${_device.deviceName}');
    } else {
      _log('Failed to connect to ${_device.deviceName}');
    }
    return success;
  }

  Future<bool> disconnect() async {
    stopScanning();
    _log('Disconnecting RFID reader...');
    return await _device.disconnect();
  }

  /// Set the active scanning mode and start background polling
  void setMode(RfidReaderMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _debouncer.reset();
    _log('Reader mode switched to: ${mode.name}');

    if (mode == RfidReaderMode.idle) {
      stopScanning();
    } else {
      _startPolling();
    }
  }

  void stopScanning() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _debouncer.reset();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Poll inventory every 250ms
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (!_device.isConnected) return;
      try {
        final tags = await _device.inventory();
        if (tags.isEmpty) return;

        if (_currentMode == RfidReaderMode.studentCardScan) {
          // In card scan mode, pick the first tag detected
          final first = tags.first;
          if (_debouncer.shouldProcess(first.cleanEpc)) {
            _log('Card detected: ${first.cleanEpc}');
            await beepSuccess();
            if (!_cardScanController.isClosed) {
              _cardScanController.add(first.cleanEpc);
            }
          }
        } else if (_currentMode == RfidReaderMode.multiTagInventory ||
            _currentMode == RfidReaderMode.diagnosticsScan) {
          // In multi-tag inventory mode, forward all detected tags
          final validNewTags = <RfidTag>[];
          for (final t in tags) {
            if (_debouncer.shouldProcess(t.cleanEpc)) {
              validNewTags.add(t);
            }
          }
          if (validNewTags.isNotEmpty) {
            _log('Detected ${validNewTags.length} new tags in field');
            await beepScan();
            if (!_inventoryController.isClosed) {
              _inventoryController.add(tags);
            }
          }
        }
      } catch (e) {
        _log('Error during inventory poll: $e');
      }
    });
  }

  // Audio/Visual Feedback Helpers
  Future<void> beepSuccess() async {
    await _device.triggerAction(beep: true, greenLed: true, durationMs: 150);
  }

  Future<void> beepScan() async {
    await _device.triggerAction(beep: true, greenLed: true, durationMs: 80);
  }

  Future<void> beepError() async {
    await _device.triggerAction(beep: true, redLed: true, durationMs: 400);
  }

  /// Write an EPC string directly to the tag in the field
  Future<bool> writeEpc(String epcHex) async {
    _log('Writing EPC: $epcHex');
    final success = await _device.writeMemory(
      bank: 1, // EPC Bank
      address: 2, // Standard EPC starts at word 2
      hexData: epcHex,
    );
    if (success) {
      _log('EPC write successful!');
      await beepSuccess();
    } else {
      _log('EPC write failed.');
      await beepError();
    }
    return success;
  }

  /// Helper for simulator injection when in simulation mode
  void simulateTagScan(List<String> epcs) {
    if (_device is SimulatedRfidDevice) {
      (_device as SimulatedRfidDevice).injectTags(epcs);
    }
  }

  void simulateClearTags() {
    if (_device is SimulatedRfidDevice) {
      (_device as SimulatedRfidDevice).clearField();
    }
  }

  void reset() {
    stopScanning();
    _debouncer.reset();
    simulateClearTags();
    _currentMode = RfidReaderMode.idle;
  }

  void dispose() {
    stopScanning();
    _device.dispose();
    if (!_cardScanController.isClosed) _cardScanController.close();
    if (!_inventoryController.isClosed) _inventoryController.close();
    if (!_logController.isClosed) _logController.close();
  }
}
