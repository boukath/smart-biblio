import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
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

/// Messages from Main Isolate to Worker Isolate
class _WorkerCommand {
  final String action;
  final int id;
  final Map<String, dynamic> params;

  _WorkerCommand(this.action, this.id, [this.params = const {}]);
}

/// Messages from Worker Isolate to Main Isolate
class _WorkerResponse {
  final int id;
  final bool success;
  final dynamic data;
  final String? error;

  _WorkerResponse({required this.id, required this.success, this.data, this.error});
}

class RfidIsolateWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  int _nextCommandId = 1;
  final Map<int, Completer<dynamic>> _pendingRequests = {};

  final StreamController<List<RfidTag>> _tagsController =
      StreamController<List<RfidTag>>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  Stream<List<RfidTag>> get onTagsDetected => _tagsController.stream;
  Stream<bool> get onConnectionChanged => _connectionStateController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize(String dllPath) async {
    if (_isInitialized) return true;

    final completer = Completer<bool>();

    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _isInitialized = true;
        completer.complete(true);
      } else if (message is _WorkerResponse) {
        final comp = _pendingRequests.remove(message.id);
        if (comp != null) {
          if (message.success) {
            comp.complete(message.data);
          } else {
            comp.completeError(message.error ?? 'Unknown error');
          }
        }
      } else if (message is Map<String, dynamic>) {
        final type = message['type'];
        if (type == 'tags') {
          final rawList = message['tags'] as List;
          final tags = rawList.map((m) => RfidTag(
            epc: m['epc'] as String,
            readCount: m['readCount'] as int,
          )).toList();
          if (!_tagsController.isClosed) {
            _tagsController.add(tags);
          }
        } else if (type == 'connectionState') {
          final isConnected = message['connected'] as bool;
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(isConnected);
          }
        }
      }
    });

    try {
      _isolate = await Isolate.spawn(
        _workerEntry,
        _IsolateInitData(_receivePort.sendPort, dllPath),
      );
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _send(String action, [Map<String, dynamic> params = const {}]) {
    if (!_isInitialized || _sendPort == null) {
      return Future.error('Isolate worker not initialized');
    }
    final id = _nextCommandId++;
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;
    _sendPort!.send(_WorkerCommand(action, id, params));
    return completer.future;
  }

  Future<bool> connect(int port, int baud) async {
    try {
      final res = await _send('connect', {'port': port, 'baud': baud});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final res = await _send('disconnect');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> startInventory(int intervalMs) async {
    try {
      await _send('startInventory', {'intervalMs': intervalMs});
    } catch (_) {}
  }

  Future<void> stopInventory() async {
    try {
      await _send('stopInventory');
    } catch (_) {}
  }

  Future<List<RfidTag>> inventoryOnce() async {
    try {
      final res = await _send('inventoryOnce');
      if (res is List) {
        return res.map((m) => RfidTag(
          epc: m['epc'] as String,
          readCount: m['readCount'] as int,
        )).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> readMemory(int bank, int address, int length) async {
    try {
      final res = await _send('readMemory', {
        'bank': bank,
        'address': address,
        'length': length,
      });
      return res as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> writeMemory(int bank, int address, String hexData) async {
    try {
      final res = await _send('writeMemory', {
        'bank': bank,
        'address': address,
        'hexData': hexData,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> triggerAction({
    bool beep = true,
    bool greenLed = true,
    bool redLed = false,
    bool yellowLed = false,
    int durationMs = 150,
  }) async {
    try {
      final res = await _send('triggerAction', {
        'beep': beep,
        'greenLed': greenLed,
        'redLed': redLed,
        'yellowLed': yellowLed,
        'durationMs': durationMs,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _sendPort?.send(_WorkerCommand('dispose', 0));
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
    _tagsController.close();
    _connectionStateController.close();
    _isInitialized = false;
  }
}

class _IsolateInitData {
  final SendPort sendPort;
  final String dllPath;
  _IsolateInitData(this.sendPort, this.dllPath);
}

/// The entry point for the background worker isolate
void _workerEntry(_IsolateInitData initData) {
  final receivePort = ReceivePort();
  initData.sendPort.send(receivePort.sendPort);

  DynamicLibrary? lib;
  UhfConnectDart? uhfConnect;
  UhfDisconnectDart? uhfDisconnect;
  UhfInventoryDart? uhfInventory;
  UhfReadDart? uhfRead;
  UhfWriteDart? uhfWrite;
  UhfActionDart? uhfAction;

  int deviceHandle = -1;
  Timer? inventoryTimer;
  bool isInventoryBusy = false;
  int consecutiveErrors = 0;

  try {
    lib = DynamicLibrary.open(initData.dllPath);
    uhfConnect = lib.lookup<NativeFunction<UhfConnectC>>('uhf_connect').asFunction();
    uhfDisconnect = lib.lookup<NativeFunction<UhfDisconnectC>>('uhf_disconnect').asFunction();
    uhfInventory = lib.lookup<NativeFunction<UhfInventoryC>>('uhf_inventory').asFunction();
    uhfRead = lib.lookup<NativeFunction<UhfReadC>>('uhf_read').asFunction();
    uhfWrite = lib.lookup<NativeFunction<UhfWriteC>>('uhf_write').asFunction();
    uhfAction = lib.lookup<NativeFunction<UhfActionC>>('uhf_action').asFunction();
  } catch (_) {
    // DLL failed to load in isolate
  }

  List<Map<String, dynamic>> performInventory() {
    if (deviceHandle <= 0 || uhfInventory == null) return [];

    final tagCountPtr = calloc<Int32>(2);
    final dataLenPtr = calloc<Int32>(2);
    final pDataR = calloc<Uint8>(4096);

    try {
      final status = uhfInventory(deviceHandle, tagCountPtr, dataLenPtr, pDataR);
      if (status != 0) {
        consecutiveErrors++;
        return [];
      }
      consecutiveErrors = 0;

      final count = tagCountPtr.value;
      if (count <= 0) return [];

      final tags = <Map<String, dynamic>>[];
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

        // Convert to standard uppercase Hex string
        // If epcBytes are already ASCII hex characters ('0'-'9', 'A'-'F'), decode directly as String.
        // Otherwise, convert each raw byte to a 2-char hex string.
        final isAsciiHex = epcBytes.length >= 16 &&
            epcBytes.every((b) => (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x46) || (b >= 0x61 && b <= 0x66));

        final hexStr = isAsciiHex
            ? String.fromCharCodes(epcBytes).toUpperCase()
            : epcBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

        if (hexStr.isNotEmpty) {
          tags.add({
            'epc': hexStr,
            'readCount': readCount > 0 ? readCount : 1,
          });
        }

        offset += dataLen + 1;
      }
      return tags;
    } catch (_) {
      consecutiveErrors++;
      return [];
    } finally {
      calloc.free(tagCountPtr);
      calloc.free(dataLenPtr);
      calloc.free(pDataR);
    }
  }

  receivePort.listen((dynamic message) async {
    if (message is! _WorkerCommand) return;
    final cmd = message;

    switch (cmd.action) {
      case 'connect':
        if (lib == null || uhfConnect == null) {
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: 'DLL not loaded'));
          return;
        }

        final port = cmd.params['port'] as int? ?? 100;
        final baud = cmd.params['baud'] as int? ?? 115200;

        try {
          if (deviceHandle > 0 && uhfDisconnect != null) {
            uhfDisconnect(deviceHandle);
            deviceHandle = -1;
          }

          final handle = uhfConnect(port, baud);
          if (handle > 0) {
            deviceHandle = handle;
            consecutiveErrors = 0;
            initData.sendPort.send(_WorkerResponse(id: cmd.id, success: true, data: true));
            initData.sendPort.send({'type': 'connectionState', 'connected': true});
          } else {
            deviceHandle = -1;
            initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: 'Connection failed'));
            initData.sendPort.send({'type': 'connectionState', 'connected': false});
          }
        } catch (e) {
          deviceHandle = -1;
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: e.toString()));
          initData.sendPort.send({'type': 'connectionState', 'connected': false});
        }
        break;

      case 'disconnect':
        inventoryTimer?.cancel();
        inventoryTimer = null;
        if (deviceHandle > 0 && uhfDisconnect != null) {
          try {
            uhfDisconnect(deviceHandle);
          } catch (_) {}
        }
        deviceHandle = -1;
        consecutiveErrors = 0;
        initData.sendPort.send(_WorkerResponse(id: cmd.id, success: true, data: true));
        initData.sendPort.send({'type': 'connectionState', 'connected': false});
        break;

      case 'startInventory':
        final interval = cmd.params['intervalMs'] as int? ?? 250;
        inventoryTimer?.cancel();
        isInventoryBusy = false;

        inventoryTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
          if (deviceHandle <= 0 || isInventoryBusy) return;
          isInventoryBusy = true;
          try {
            final tags = performInventory();
            if (tags.isNotEmpty) {
              initData.sendPort.send({'type': 'tags', 'tags': tags});
            } else if (consecutiveErrors >= 5) {
              // Device unplugged or stopped responding
              deviceHandle = -1;
              inventoryTimer?.cancel();
              inventoryTimer = null;
              initData.sendPort.send({'type': 'connectionState', 'connected': false});
            }
          } finally {
            isInventoryBusy = false;
          }
        });
        initData.sendPort.send(_WorkerResponse(id: cmd.id, success: true, data: true));
        break;

      case 'stopInventory':
        inventoryTimer?.cancel();
        inventoryTimer = null;
        isInventoryBusy = false;
        initData.sendPort.send(_WorkerResponse(id: cmd.id, success: true, data: true));
        break;

      case 'inventoryOnce':
        final tags = performInventory();
        initData.sendPort.send(_WorkerResponse(id: cmd.id, success: true, data: tags));
        break;

      case 'readMemory':
        if (deviceHandle <= 0 || uhfRead == null) {
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: 'Not connected'));
          return;
        }
        final bank = cmd.params['bank'] as int;
        final address = cmd.params['address'] as int;
        final length = cmd.params['length'] as int;

        final pDataR = calloc<Uint8>(1024);
        try {
          final st = uhfRead(deviceHandle, bank, address, length, pDataR);
          if (st != 0) {
            initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: 'Read error: $st'));
          } else {
            final totalBytes = length * 4;
            final bytes = <int>[];
            for (int i = 0; i < totalBytes; i++) {
              bytes.add(pDataR[i]);
            }
            final hex = bytes
                .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                .join();
            initData.sendPort.send(_WorkerResponse(id: cmd.id, success: true, data: hex));
          }
        } finally {
          calloc.free(pDataR);
        }
        break;

      case 'writeMemory':
        if (deviceHandle <= 0 || uhfWrite == null) {
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: 'Not connected'));
          return;
        }
        final bank = cmd.params['bank'] as int;
        final address = cmd.params['address'] as int;
        final hexData = cmd.params['hexData'] as String;

        // Temporarily pause inventory timer during write to avoid USB bus collisions
        final wasInventoryRunning = inventoryTimer != null;
        if (wasInventoryRunning) {
          inventoryTimer?.cancel();
          inventoryTimer = null;
        }

        // Brief delay to allow USB/serial RF hardware buffers to clear
        await Future.delayed(const Duration(milliseconds: 60));

        final clean = hexData.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        int st = -1;

        // 1. Primary write method: Fongwah SDK standard (ASCII character bytes)
        // In the official SDK (Form1.cs / sample.frm):
        // bufDataW contains ASCII codes (e.g. 0x31 for '1', 0x41 for 'A').
        // For EPC (bank 1), address = 2, length = 6 writes 24 ASCII characters (96 bits).
        if (bank == 1) {
          final epc24 = clean.padRight(24, '0').substring(0, 24);
          final asciiPtr = calloc<Uint8>(32);
          for (int i = 0; i < 24; i++) {
            asciiPtr[i] = epc24.codeUnitAt(i);
          }
          asciiPtr[24] = 0;

          try {
            // Attempt standard write with retry
            for (int attempt = 0; attempt < 3; attempt++) {
              st = uhfWrite(deviceHandle, bank, address, 6, asciiPtr);
              if (st == 0) break;
              await Future.delayed(const Duration(milliseconds: 60));
            }

            // Fallback A: Try with address 1 (some tags with PC word offset)
            if (st != 0 && address != 1) {
              st = uhfWrite(deviceHandle, bank, 1, 6, asciiPtr);
            }
          } finally {
            calloc.free(asciiPtr);
          }
        } else {
          // Non-EPC bank (e.g., USER or RESERVED)
          final wlen = (clean.length / 4).ceil().clamp(1, 16);
          final asciiPtr = calloc<Uint8>(wlen * 4 + 4);
          final padded = clean.padRight(wlen * 4, '0');
          for (int i = 0; i < padded.length; i++) {
            asciiPtr[i] = padded.codeUnitAt(i);
          }
          try {
            st = uhfWrite(deviceHandle, bank, address, wlen, asciiPtr);
          } finally {
            calloc.free(asciiPtr);
          }
        }

        // Fallback B: If ASCII write failed, try raw binary bytes (for firmware variants expecting binary payload)
        if (st != 0) {
          final byteList = <int>[];
          for (int i = 0; i < clean.length; i += 2) {
            if (i + 1 < clean.length) {
              byteList.add(int.parse(clean.substring(i, i + 2), radix: 16));
            }
          }
          while (byteList.length % 4 != 0) {
            byteList.add(0);
          }
          final words = byteList.length ~/ 4;
          final pDataW = calloc<Uint8>(byteList.length);
          for (int i = 0; i < byteList.length; i++) {
            pDataW[i] = byteList[i];
          }

          try {
            st = uhfWrite(deviceHandle, bank, address, words, pDataW);
            if (st != 0 && bank == 1 && words < 6) {
              final padded24 = calloc<Uint8>(24);
              try {
                for (int i = 0; i < 24; i++) {
                  padded24[i] = i < byteList.length ? byteList[i] : 0;
                }
                st = uhfWrite(deviceHandle, bank, address, 6, padded24);
              } finally {
                calloc.free(padded24);
              }
            }
          } finally {
            calloc.free(pDataW);
          }
        }

        // On success, trigger reader hardware beep & green LED
        if (st == 0 && uhfAction != null) {
          try {
            uhfAction(deviceHandle, 0x01 | 0x04, 20); // 200ms beep + green LED
          } catch (_) {}
        }

        initData.sendPort.send(_WorkerResponse(id: cmd.id, success: st == 0, data: st == 0));

        // Resume inventory timer if it was active before writing
        if (wasInventoryRunning && inventoryTimer == null) {
          inventoryTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
            if (isInventoryBusy || deviceHandle <= 0 || uhfInventory == null) return;
            isInventoryBusy = true;
            try {
              final tags = performInventory();
              if (tags.isNotEmpty) {
                initData.sendPort.send({'type': 'tags', 'tags': tags});
              }
            } finally {
              isInventoryBusy = false;
            }
          });
        }
        break;

      case 'triggerAction':
        if (deviceHandle <= 0 || uhfAction == null) {
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false, error: 'Not connected'));
          return;
        }
        int action = 0;
        if (cmd.params['beep'] == true) action |= 0x01;
        if (cmd.params['redLed'] == true) action |= 0x02;
        if (cmd.params['greenLed'] == true) action |= 0x04;
        if (cmd.params['yellowLed'] == true) action |= 0x08;

        final durationMs = cmd.params['durationMs'] as int? ?? 150;
        final timeUnits = (durationMs ~/ 10).clamp(1, 255);

        try {
          final st = uhfAction(deviceHandle, action, timeUnits);
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: st == 0, data: st == 0));
        } catch (_) {
          initData.sendPort.send(_WorkerResponse(id: cmd.id, success: false));
        }
        break;

      case 'dispose':
        inventoryTimer?.cancel();
        if (deviceHandle > 0 && uhfDisconnect != null) {
          try {
            uhfDisconnect(deviceHandle);
          } catch (_) {}
        }
        receivePort.close();
        break;
    }
  });
}
