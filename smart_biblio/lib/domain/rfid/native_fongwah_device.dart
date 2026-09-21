import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'rfid_device_interface.dart';
import 'rfid_models.dart';

// FFI Typedefs
typedef UhfConnectC = Int32 Function(Int16 port, Int32 baud);
typedef UhfConnectDart = int Function(int port, int baud);

typedef UhfDisconnectC = Int32 Function(Int32 icdev);
typedef UhfDisconnectDart = int Function(int icdev);

typedef UhfInventoryC = Int32 Function(
  Int32 icdev,
  Pointer<Int32> tagCount,
  Pointer<Int32> datalen,
  Pointer<Uint8> pDataR,
);
typedef UhfInventoryDart = int Function(
  int icdev,
  Pointer<Int32> tagCount,
  Pointer<Int32> datalen,
  Pointer<Uint8> pDataR,
);

typedef UhfReadC = Int32 Function(
  Int32 icdev,
  Uint8 infoType,
  Int32 address,
  Int32 rlen,
  Pointer<Uint8> pDataR,
);
typedef UhfReadDart = int Function(
  int icdev,
  int infoType,
  int address,
  int rlen,
  Pointer<Uint8> pDataR,
);

typedef UhfWriteC = Int32 Function(
  Int32 icdev,
  Uint8 infoType,
  Int32 address,
  Int32 wlen,
  Pointer<Uint8> pDataW,
);
typedef UhfWriteDart = int Function(
  int icdev,
  int infoType,
  int address,
  int wlen,
  Pointer<Uint8> pDataW,
);

typedef UhfActionC = Int32 Function(
  Int32 icdev,
  Uint8 action,
  Uint8 time,
);
typedef UhfActionDart = int Function(
  int icdev,
  int action,
  int time,
);

class NativeFongwahRfidDevice implements RfidDeviceInterface {
  @override
  final String deviceName = 'Fongwah U1-CU-71 UHF RFID Reader/Writer (Native SDK)';

  DynamicLibrary? _lib;
  int _deviceHandle = -1;
  RfidConnectionState _connectionState = RfidConnectionState.disconnected;
  final StreamController<RfidConnectionState> _stateController =
      StreamController<RfidConnectionState>.broadcast();

  // Function Pointers
  UhfConnectDart? _uhfConnect;
  UhfDisconnectDart? _uhfDisconnect;
  UhfInventoryDart? _uhfInventory;
  UhfReadDart? _uhfRead;
  UhfWriteDart? _uhfWrite;
  UhfActionDart? _uhfAction;

  NativeFongwahRfidDevice() {
    _loadDll();
  }

  bool get isDllLoaded => _lib != null;

  void _loadDll() {
    final possiblePaths = [
      'E7umf.dll',
      'assets/dll/x64/E7umf.dll',
      'windows/E7umf.dll',
      r'..\assets\dll\x64\E7umf.dll',
      r'U1-CU-71 UHF Reader SDK 20240912\U1-CU-71 UHF Reader SDK 20240912\U1-CU-71 UHF Reader SDK 20240912\Software Application\Win64-dll\E7umf.dll',
    ];

    for (final path in possiblePaths) {
      try {
        if (File(path).existsSync()) {
          _lib = DynamicLibrary.open(File(path).absolute.path);
          break;
        }
      } catch (_) {}
    }

    if (_lib == null) {
      try {
        _lib = DynamicLibrary.open('E7umf.dll');
      } catch (e) {
        // DLL not found in system path; will stay unloaded
        _lib = null;
      }
    }

    if (_lib != null) {
      try {
        _uhfConnect = _lib!
            .lookup<NativeFunction<UhfConnectC>>('uhf_connect')
            .asFunction();
        _uhfDisconnect = _lib!
            .lookup<NativeFunction<UhfDisconnectC>>('uhf_disconnect')
            .asFunction();
        _uhfInventory = _lib!
            .lookup<NativeFunction<UhfInventoryC>>('uhf_inventory')
            .asFunction();
        _uhfRead =
            _lib!.lookup<NativeFunction<UhfReadC>>('uhf_read').asFunction();
        _uhfWrite =
            _lib!.lookup<NativeFunction<UhfWriteC>>('uhf_write').asFunction();
        _uhfAction =
            _lib!.lookup<NativeFunction<UhfActionC>>('uhf_action').asFunction();
      } catch (e) {
        _lib = null;
      }
    }
  }

  void _setState(RfidConnectionState state) {
    _connectionState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  RfidConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected => _deviceHandle > 0 && _connectionState == RfidConnectionState.connected;

  @override
  Stream<RfidConnectionState> get connectionStateStream => _stateController.stream;

  @override
  Future<bool> connect({int port = 100, int baud = 115200}) async {
    if (!isDllLoaded) {
      _loadDll();
      if (!isDllLoaded) {
        _setState(RfidConnectionState.error);
        return false;
      }
    }

    _setState(RfidConnectionState.connecting);

    try {
      final handle = _uhfConnect!(port, baud);
      if (handle > 0) {
        _deviceHandle = handle;
        _setState(RfidConnectionState.connected);
        // Beep short welcome
        await triggerAction(beep: true, greenLed: true, durationMs: 150);
        return true;
      } else {
        _deviceHandle = -1;
        _setState(RfidConnectionState.disconnected);
        return false;
      }
    } catch (e) {
      _deviceHandle = -1;
      _setState(RfidConnectionState.error);
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    if (_deviceHandle <= 0) {
      _setState(RfidConnectionState.disconnected);
      return true;
    }

    try {
      _uhfDisconnect!(_deviceHandle);
      _deviceHandle = -1;
      _setState(RfidConnectionState.disconnected);
      return true;
    } catch (e) {
      _deviceHandle = -1;
      _setState(RfidConnectionState.disconnected);
      return false;
    }
  }

  @override
  Future<List<RfidTag>> inventory() async {
    if (!isConnected || _uhfInventory == null) return [];

    final tagCountPtr = calloc<Int32>(2);
    final dataLenPtr = calloc<Int32>(2);
    final pDataR = calloc<Uint8>(4096);

    try {
      final status = _uhfInventory!(_deviceHandle, tagCountPtr, dataLenPtr, pDataR);
      if (status != 0) return [];

      final count = tagCountPtr.value;
      if (count <= 0) return [];

      final tags = <RfidTag>[];
      int offset = 0;

      for (int i = 0; i < count; i++) {
        final dataLen = pDataR[offset];
        if (dataLen <= 1) break;

        final readCount = pDataR[offset + 1];
        final epcLen = dataLen - 1;

        final epcBytes = <int>[];
        for (int b = 0; b < epcLen; b++) {
          epcBytes.add(pDataR[offset + 2 + b]);
        }

        // Clean ASCII string if printable, otherwise hex string
        String epcStr;
        final isAscii = epcBytes.every((b) => b >= 32 && b <= 126);
        if (isAscii && epcBytes.isNotEmpty) {
          epcStr = ascii.decode(epcBytes).trim();
        } else {
          epcStr = epcBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join();
        }

        if (epcStr.isNotEmpty) {
          tags.add(RfidTag(
            epc: epcStr,
            readCount: readCount > 0 ? readCount : 1,
          ));
        }

        offset += dataLen + 1;
      }

      return tags;
    } catch (e) {
      return [];
    } finally {
      calloc.free(tagCountPtr);
      calloc.free(dataLenPtr);
      calloc.free(pDataR);
    }
  }

  @override
  Future<String?> readMemory({
    required int bank,
    int address = 0,
    int length = 8,
  }) async {
    if (!isConnected || _uhfRead == null) return null;

    final pDataR = calloc<Uint8>(1024);
    try {
      final st = _uhfRead!(_deviceHandle, bank, address, length, pDataR);
      if (st != 0) return null;

      final bytes = <int>[];
      final totalBytes = length * 4; // Length units = 4 bytes (words)
      for (int i = 0; i < totalBytes; i++) {
        final val = pDataR[i];
        if (val == 0 && i > 0) break;
        bytes.add(val);
      }

      final isAscii = bytes.every((b) => b >= 32 && b <= 126);
      if (isAscii && bytes.isNotEmpty) {
        return ascii.decode(bytes).trim();
      } else {
        return bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join();
      }
    } catch (e) {
      return null;
    } finally {
      calloc.free(pDataR);
    }
  }

  @override
  Future<bool> writeMemory({
    required int bank,
    int address = 2,
    required String hexData,
  }) async {
    if (!isConnected || _uhfWrite == null) return false;

    // Convert hexData string to bytes
    final clean = hexData.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final byteList = <int>[];
    for (int i = 0; i < clean.length; i += 2) {
      if (i + 1 < clean.length) {
        byteList.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
    }

    if (byteList.isEmpty) return false;

    // Ensure 4-byte word alignment
    while (byteList.length % 4 != 0) {
      byteList.add(0);
    }

    final words = byteList.length ~/ 4;
    final pDataW = calloc<Uint8>(byteList.length);
    for (int i = 0; i < byteList.length; i++) {
      pDataW[i] = byteList[i];
    }

    try {
      final st = _uhfWrite!(_deviceHandle, bank, address, words, pDataW);
      return st == 0;
    } catch (e) {
      return false;
    } finally {
      calloc.free(pDataW);
    }
  }

  @override
  Future<bool> triggerAction({
    bool beep = true,
    bool greenLed = true,
    bool redLed = false,
    bool yellowLed = false,
    int durationMs = 300,
  }) async {
    if (!isConnected || _uhfAction == null) return false;

    int action = 0;
    if (beep) action |= 0x01;
    if (redLed) action |= 0x02;
    if (greenLed) action |= 0x04;
    if (yellowLed) action |= 0x08;

    // Time is in 10ms units
    final timeUnits = (durationMs ~/ 10).clamp(1, 255);

    try {
      final st = _uhfAction!(_deviceHandle, action, timeUnits);
      return st == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    if (isConnected) {
      disconnect();
    }
    _stateController.close();
  }
}
