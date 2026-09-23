import 'dart:async';
import 'dart:io';
import 'rfid_device_interface.dart';
import 'rfid_isolate_worker.dart';
import 'rfid_models.dart';

class NativeFongwahRfidDevice implements RfidDeviceInterface {
  @override
  final String deviceName = 'Fongwah U1-CU-71 UHF RFID Reader/Writer (Native SDK)';

  String? _dllPath;
  RfidIsolateWorker? _worker;
  RfidConnectionState _connectionState = RfidConnectionState.disconnected;
  final StreamController<RfidConnectionState> _stateController =
      StreamController<RfidConnectionState>.broadcast();

  StreamSubscription<List<RfidTag>>? _tagsSub;
  StreamSubscription<bool>? _connSub;

  final StreamController<List<RfidTag>> _inventoryStreamController =
      StreamController<List<RfidTag>>.broadcast();
  Stream<List<RfidTag>> get onTagsStream => _inventoryStreamController.stream;

  NativeFongwahRfidDevice() {
    _findDll();
  }

  bool get isDllLoaded => _dllPath != null;

  void _findDll() {
    final possiblePaths = [
      'E7umf.dll',
      'assets/dll/x64/E7umf.dll',
      'windows/E7umf.dll',
      r'..\assets\dll\x64\E7umf.dll',
      r'U1-CU-71 UHF Reader SDK 20240912\U1-CU-71 UHF Reader SDK 20240912\U1-CU-71 UHF Reader SDK 20240912\Software Application\Win64-dll\E7umf.dll',
    ];

    for (final path in possiblePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          _dllPath = f.absolute.path;
          break;
        }
      } catch (_) {}
    }

    if (_dllPath == null) {
      final f = File('E7umf.dll');
      if (f.existsSync()) {
        _dllPath = f.absolute.path;
      }
    }
  }

  void _setState(RfidConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  RfidConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected => _connectionState == RfidConnectionState.connected;

  @override
  Stream<RfidConnectionState> get connectionStateStream => _stateController.stream;

  Future<bool> _ensureWorker() async {
    if (_worker != null && _worker!.isInitialized) return true;
    if (_dllPath == null) {
      _findDll();
      if (_dllPath == null) return false;
    }

    _worker?.dispose();
    _worker = RfidIsolateWorker();
    final ok = await _worker!.initialize(_dllPath!);
    if (!ok) return false;

    _tagsSub?.cancel();
    _tagsSub = _worker!.onTagsDetected.listen((tags) {
      if (!_inventoryStreamController.isClosed) {
        _inventoryStreamController.add(tags);
      }
    });

    _connSub?.cancel();
    _connSub = _worker!.onConnectionChanged.listen((connected) {
      if (!connected && _connectionState == RfidConnectionState.connected) {
        _setState(RfidConnectionState.disconnected);
      }
    });

    return true;
  }

  @override
  Future<bool> connect({int port = 100, int baud = 115200}) async {
    if (!isDllLoaded) {
      _findDll();
      if (!isDllLoaded) {
        _setState(RfidConnectionState.error);
        return false;
      }
    }

    _setState(RfidConnectionState.connecting);

    final ready = await _ensureWorker();
    if (!ready) {
      _setState(RfidConnectionState.error);
      return false;
    }

    try {
      final success = await _worker!.connect(port, baud);
      if (success) {
        _setState(RfidConnectionState.connected);
        return true;
      } else {
        _setState(RfidConnectionState.disconnected);
        return false;
      }
    } catch (_) {
      _setState(RfidConnectionState.error);
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    if (_connectionState == RfidConnectionState.disconnected) return true;

    if (_worker != null && _worker!.isInitialized) {
      await _worker!.disconnect();
    }
    _setState(RfidConnectionState.disconnected);
    return true;
  }

  @override
  Future<List<RfidTag>> inventory() async {
    if (!isConnected || _worker == null) return [];
    return await _worker!.inventoryOnce();
  }

  Future<void> startBackgroundInventory({int intervalMs = 250}) async {
    if (_worker != null && _worker!.isInitialized) {
      await _worker!.startInventory(intervalMs);
    }
  }

  Future<void> stopBackgroundInventory() async {
    if (_worker != null && _worker!.isInitialized) {
      await _worker!.stopInventory();
    }
  }

  @override
  Future<String?> readMemory({
    required int bank,
    int address = 0,
    int length = 8,
  }) async {
    if (!isConnected || _worker == null) return null;
    return await _worker!.readMemory(bank, address, length);
  }

  @override
  Future<bool> writeMemory({
    required int bank,
    int address = 2,
    required String hexData,
  }) async {
    if (!isConnected || _worker == null) return false;
    return await _worker!.writeMemory(bank, address, hexData);
  }

  @override
  Future<bool> triggerAction({
    bool beep = true,
    bool greenLed = true,
    bool redLed = false,
    bool yellowLed = false,
    int durationMs = 150,
  }) async {
    if (!isConnected || _worker == null) return false;
    return await _worker!.triggerAction(
      beep: beep,
      greenLed: greenLed,
      redLed: redLed,
      yellowLed: yellowLed,
      durationMs: durationMs,
    );
  }

  @override
  void dispose() {
    _tagsSub?.cancel();
    _connSub?.cancel();
    _worker?.dispose();
    _worker = null;
    _setState(RfidConnectionState.disconnected);
    _stateController.close();
    _inventoryStreamController.close();
  }
}
