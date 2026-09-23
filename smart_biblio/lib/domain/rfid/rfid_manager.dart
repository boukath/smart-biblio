import 'dart:async';
import '../../core/utils/tag_debouncer.dart';
import 'native_fongwah_device.dart';
import 'rfid_device_interface.dart';
import 'rfid_models.dart';
import 'simulated_rfid_device.dart';
import 'windows_port_detector.dart';

class RfidManager {
  static final RfidManager _instance = RfidManager._internal();
  factory RfidManager() => _instance;
  RfidManager._internal() {
    _initDevice();
  }

  late RfidDeviceInterface _device;
  bool _useSimulation = false;
  RfidReaderMode _currentMode = RfidReaderMode.idle;
  Timer? _simulatedPollingTimer;
  StreamSubscription<List<RfidTag>>? _nativeTagsSub;
  StreamSubscription<RfidConnectionState>? _deviceStateSub;

  final TagDebouncer _debouncer = TagDebouncer();

  // Auto-reconnect & hotplug
  Timer? _autoReconnectTimer;
  final bool _autoReconnectEnabled = true;
  int? _lastConnectedPort;
  int _lastBaud = 115200;

  // Stream Controllers
  final StreamController<String> _cardScanController =
      StreamController<String>.broadcast();
  final StreamController<List<RfidTag>> _inventoryController =
      StreamController<List<RfidTag>>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<RfidConnectionState> _connectionStateController =
      StreamController<RfidConnectionState>.broadcast();

  // Getters
  RfidDeviceInterface get device => _device;
  bool get isSimulated => _useSimulation;
  RfidReaderMode get currentMode => _currentMode;
  bool get isConnected => _device.isConnected;
  int? get currentPort => _lastConnectedPort;

  Stream<String> get onCardDetected => _cardScanController.stream;
  Stream<List<RfidTag>> get onTagsInventory => _inventoryController.stream;
  Stream<String> get onLogMessage => _logController.stream;
  Stream<RfidConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;

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
        _log('Initialized Native Fongwah U1-CU-71 Driver (Background Isolate)');
      } else {
        _useSimulation = true;
        _device = SimulatedRfidDevice();
        _log('DLL not accessible, falling back to Virtual RFID Simulator');
      }
    }
    _listenDeviceState();
  }

  void _listenDeviceState() {
    _deviceStateSub?.cancel();
    _deviceStateSub = _device.connectionStateStream.listen((state) {
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(state);
      }
      if (state == RfidConnectionState.disconnected && !_useSimulation) {
        _log('RFID Reader disconnected.');
        _startAutoReconnectTimer();
      } else if (state == RfidConnectionState.connected) {
        _stopAutoReconnectTimer();
      }
    });
  }

  void _startAutoReconnectTimer() {
    if (!_autoReconnectEnabled || _useSimulation) return;
    if (_autoReconnectTimer != null && _autoReconnectTimer!.isActive) return;

    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_device.isConnected) {
        _stopAutoReconnectTimer();
        return;
      }
      _log('Checking for reconnected RFID reader...');
      final bestPort = await WindowsPortDetector.findBestFongwahPort();
      if (bestPort != null) {
        final success = await _device.connect(port: bestPort, baud: _lastBaud);
        if (success) {
          _lastConnectedPort = bestPort;
          _log('Auto-reconnected to RFID reader on port $bestPort!');
          _stopAutoReconnectTimer();
          // Resume current scanning mode if needed
          if (_currentMode != RfidReaderMode.idle) {
            _startPolling();
          }
        }
      }
    });
  }

  void _stopAutoReconnectTimer() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
  }

  /// Switch between Native SDK and Virtual Simulator
  Future<void> setSimulationMode(bool enabled) async {
    if (_useSimulation == enabled) return;
    _log('Switching reader mode: simulation = $enabled');
    _stopAutoReconnectTimer();
    await disconnect();
    _device.dispose();
    _useSimulation = enabled;
    if (_useSimulation) {
      _device = SimulatedRfidDevice();
    } else {
      _device = NativeFongwahRfidDevice();
    }
    _listenDeviceState();
    await connect();
  }

  /// Connect to reader with smart auto-detection if port is not explicitly specified.
  Future<bool> connect({int? port, int baud = 115200}) async {
    _lastBaud = baud;

    if (_useSimulation) {
      final success = await _device.connect(port: port ?? 100, baud: baud);
      _lastConnectedPort = port ?? 100;
      return success;
    }

    // If port explicitly given (e.g. from UI selector), try that port
    if (port != null) {
      _log('Connecting to RFID reader (Port: $port, Baud: $baud)...');
      final success = await _device.connect(port: port, baud: baud);
      if (success) {
        _lastConnectedPort = port;
        _log('Connected successfully to ${_device.deviceName} on port $port');
        _stopAutoReconnectTimer();
        if (_currentMode != RfidReaderMode.idle) {
          _startPolling();
        }
        return true;
      } else {
        _log('Failed to connect to ${_device.deviceName} on port $port');
        _startAutoReconnectTimer();
        return false;
      }
    }

    // Auto-detect ports on Windows (skips unresponsive motherboard headers)
    _log('Auto-detecting connected RFID reader ports...');
    final detectedPorts = await WindowsPortDetector.getCandidatePortsForAutoConnect();
    _log('Found ${detectedPorts.length} potential port(s): ${detectedPorts.map((p) => p.label).join(', ')}');

    for (final candidate in detectedPorts) {
      _log('Trying port ${candidate.portIndex} (${candidate.label})...');
      final success = await _device.connect(port: candidate.portIndex, baud: baud);
      if (success) {
        _lastConnectedPort = candidate.portIndex;
        _log('Connected successfully to RFID reader on ${candidate.label}!');
        _stopAutoReconnectTimer();
        if (_currentMode != RfidReaderMode.idle) {
          _startPolling();
        }
        return true;
      }
    }

    _log('Could not automatically connect to RFID reader. Will auto-retry on reconnect.');
    _startAutoReconnectTimer();
    return false;
  }

  Future<bool> disconnect() async {
    _stopAutoReconnectTimer();
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
    _simulatedPollingTimer?.cancel();
    _simulatedPollingTimer = null;
    _nativeTagsSub?.cancel();
    _nativeTagsSub = null;

    if (_device is NativeFongwahRfidDevice) {
      (_device as NativeFongwahRfidDevice).stopBackgroundInventory();
    }
    _debouncer.reset();
  }

  void _startPolling() {
    stopScanning();

    if (_device is NativeFongwahRfidDevice) {
      final native = _device as NativeFongwahRfidDevice;
      _nativeTagsSub = native.onTagsStream.listen((tags) {
        _processDetectedTags(tags);
      });
      native.startBackgroundInventory(intervalMs: 250);
    } else {
      // Simulated device polling on UI isolate
      _simulatedPollingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
        if (!_device.isConnected) return;
        try {
          final tags = await _device.inventory();
          if (tags.isNotEmpty) {
            _processDetectedTags(tags);
          }
        } catch (_) {}
      });
    }
  }

  void _processDetectedTags(List<RfidTag> tags) async {
    if (tags.isEmpty) return;

    if (_currentMode == RfidReaderMode.studentCardScan) {
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
      final validNewTags = <RfidTag>[];
      for (final t in tags) {
        if (_debouncer.shouldProcess(t.cleanEpc)) {
          validNewTags.add(t);
        }
      }
      if (validNewTags.isNotEmpty) {
        _log('Detected ${validNewTags.length} new tags in field: ${validNewTags.map((t) => t.cleanEpc).join(', ')}');
        await beepScan();
        if (!_inventoryController.isClosed) {
          _inventoryController.add(tags);
        }
      }
    }
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

  /// Check whether an EPC represents an empty, blank, or factory-zeroed tag
  static bool isBlankOrEmptyEpc(String? epc) {
    if (epc == null) return true;
    final clean = epc.trim().toUpperCase();
    if (clean.isEmpty) return true;
    if (clean.contains('EMPTY') || clean.contains('BLANK')) return true;
    final hexOnly = clean.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (hexOnly.isEmpty) return true;
    // Check if tag is filled only with zeros (common for factory blank tags)
    if (hexOnly.replaceAll('0', '').isEmpty) return true;
    return false;
  }

  /// Formats a student ID into a 24-character hexadecimal EPC string (96-bit Gen2 EPC)
  static String formatStudentIdToHexEpc(String id) {
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      buffer.write(clean.codeUnitAt(i).toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    String hex = buffer.toString();
    if (hex.length < 24) {
      hex = hex.padRight(24, '0');
    } else if (hex.length > 24) {
      hex = hex.substring(0, 24);
    }
    return hex;
  }

  /// Decodes ASCII characters from a 24-character hex EPC
  static String decodeHexEpcToText(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i += 2) {
      if (i + 1 < clean.length) {
        final code = int.tryParse(clean.substring(i, i + 2), radix: 16) ?? 0;
        if (code >= 32 && code <= 126) {
          buffer.writeCharCode(code);
        }
      }
    }
    return buffer.toString().trim();
  }

  /// Writes and activates a student card directly from the student number
  Future<bool> activateAndWriteStudentCard({required String studentNumber}) async {
    final targetEpc = formatStudentIdToHexEpc(studentNumber);
    _log('Activating student card for $studentNumber -> EPC $targetEpc');
    return await writeEpc(targetEpc);
  }

  /// Read memory from a specific bank of the active tag
  Future<String?> readTagMemory({required int bank, int address = 0, int length = 8}) async {
    return await _device.readMemory(bank: bank, address: address, length: length);
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
    _stopAutoReconnectTimer();
    stopScanning();
    _deviceStateSub?.cancel();
    _device.dispose();
    if (!_cardScanController.isClosed) _cardScanController.close();
    if (!_inventoryController.isClosed) _inventoryController.close();
    if (!_logController.isClosed) _logController.close();
    if (!_connectionStateController.isClosed) _connectionStateController.close();
  }
}
