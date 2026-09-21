enum RfidConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

enum RfidReaderMode {
  idle,
  studentCardScan,
  multiTagInventory,
  diagnosticsScan,
  tagWriter,
}

class RfidTag {
  final String epc;
  final String? tid;
  final String? userData;
  final int readCount;
  final int? rssi;
  final DateTime timestamp;

  RfidTag({
    required this.epc,
    this.tid,
    this.userData,
    this.readCount = 1,
    this.rssi,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get cleanEpc => epc.trim().toUpperCase();

  @override
  String toString() => 'RfidTag(epc: $cleanEpc, count: $readCount, tid: $tid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RfidTag &&
          runtimeType == other.runtimeType &&
          cleanEpc == other.cleanEpc;

  @override
  int get hashCode => cleanEpc.hashCode;
}

class RfidDeviceInfo {
  final String name;
  final int port; // 100 for USB, 0 for COM1, 1 for COM2...
  final int baud;
  final bool isSimulated;
  final String firmwareVersion;

  const RfidDeviceInfo({
    required this.name,
    required this.port,
    this.baud = 115200,
    this.isSimulated = false,
    this.firmwareVersion = 'U1-CU-71 V02',
  });

  String get portLabel => port == 100 ? 'USB (Default)' : 'COM$port';
}
