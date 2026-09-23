import 'dart:async';
import 'dart:io';

class DetectedPort {
  final int portIndex; // Index for Fongwah SDK (0 = COM1, 9 = COM10, 100 = USB HID)
  final String label;
  final String? systemPortName; // e.g. 'COM10'
  final bool isFongwahLikely; // Matched Fongwah VID/PID or device name
  final bool isUsbSerial; // True if port is a USB-to-serial adapter/device

  const DetectedPort({
    required this.portIndex,
    required this.label,
    this.systemPortName,
    this.isFongwahLikely = false,
    this.isUsbSerial = false,
  });

  @override
  String toString() => '$label (port $portIndex, fongwah: $isFongwahLikely, usb: $isUsbSerial)';
}

class WindowsPortDetector {
  /// Scans Windows system for active COM ports and USB devices suitable for Fongwah RFID.
  static Future<List<DetectedPort>> detectAvailablePorts() async {
    final ports = <DetectedPort>[];
    final seenIndices = <int>{};

    // Always include USB HID direct option (100)
    ports.add(const DetectedPort(
      portIndex: 100,
      label: 'USB HID Direct (Port 100)',
      isFongwahLikely: false,
      isUsbSerial: true,
    ));
    seenIndices.add(100);

    if (!Platform.isWindows) {
      return ports;
    }

    // 1. Query Windows Registry for active serial ports: HKLM\HARDWARE\DEVICEMAP\SERIALCOMM
    final registryComPorts = await _getRegistryComPorts();

    // 2. Query Windows PnP for USB Serial Devices (especially VID_2E3C for Fongwah)
    final pnpFongwahComPorts = await _getPnpFongwahComPorts();

    for (final entry in registryComPorts.entries) {
      final comStr = entry.key;
      final isUsb = entry.value;
      final portNum = _parseComNumber(comStr);
      if (portNum != null && portNum >= 1) {
        final portIdx = portNum - 1; // 0-indexed in Fongwah SDK
        if (!seenIndices.contains(portIdx)) {
          seenIndices.add(portIdx);
          final isFongwah = pnpFongwahComPorts.contains(comStr.toUpperCase());
          String label;
          if (isFongwah) {
            label = '$comStr - Fongwah RFID Reader (Recommended)';
          } else if (isUsb) {
            label = '$comStr - USB Serial Device';
          } else {
            label = '$comStr - Motherboard Serial Header';
          }

          ports.add(DetectedPort(
            portIndex: portIdx,
            label: label,
            systemPortName: comStr,
            isFongwahLikely: isFongwah,
            isUsbSerial: isUsb,
          ));
        }
      }
    }

    // Sort: Fongwah likely first, then USB serial, then USB HID (100), then other COM ports
    ports.sort((a, b) {
      if (a.isFongwahLikely && !b.isFongwahLikely) return -1;
      if (!a.isFongwahLikely && b.isFongwahLikely) return 1;
      if (a.isUsbSerial && !b.isUsbSerial) return -1;
      if (!a.isUsbSerial && b.isUsbSerial) return 1;
      return a.portIndex.compareTo(b.portIndex);
    });

    return ports;
  }

  /// Returns candidate ports safe for automated scanning/probing.
  /// Ignores non-USB motherboard serial ports (e.g. COM1) to prevent long timeouts.
  static Future<List<DetectedPort>> getCandidatePortsForAutoConnect() async {
    final all = await detectAvailablePorts();
    return all.where((p) => p.isFongwahLikely || p.isUsbSerial || p.portIndex == 100).toList();
  }

  /// Automatically picks the best candidate port for Fongwah reader.
  static Future<int?> findBestFongwahPort() async {
    final candidates = await getCandidatePortsForAutoConnect();
    if (candidates.isNotEmpty) {
      return candidates.first.portIndex;
    }
    return 100;
  }

  static int? _parseComNumber(String comStr) {
    final match = RegExp(r'COM(\d+)', caseSensitive: false).firstMatch(comStr);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static Future<Map<String, bool>> _getRegistryComPorts() async {
    final comMap = <String, bool>{};
    try {
      final res = await Process.run('reg', [
        'query',
        r'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM',
      ]);
      if (res.exitCode == 0 && res.stdout is String) {
        final lines = (res.stdout as String).split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.contains('REG_SZ')) {
            final parts = trimmed.split(RegExp(r'\s+REG_SZ\s+'));
            if (parts.length >= 2) {
              final devicePath = parts[0].trim().toUpperCase();
              final comName = parts[1].trim().toUpperCase();
              if (comName.startsWith('COM')) {
                final isUsb = devicePath.contains('USBSER') || !devicePath.contains('SERIAL0');
                comMap[comName] = isUsb;
              }
            }
          }
        }
      }
    } catch (_) {}
    return comMap;
  }

  static Future<Set<String>> _getPnpFongwahComPorts() async {
    final result = <String>{};
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "2E3C|5740" -or $_.FriendlyName -match "Fongwah|UHF" } | Select-Object -ExpandProperty FriendlyName',
      ]);
      if (res.exitCode == 0 && res.stdout is String) {
        final lines = (res.stdout as String).split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          final match = RegExp(r'(COM\d+)', caseSensitive: false).firstMatch(line);
          if (match != null) {
            result.add(match.group(1)!.toUpperCase());
          }
        }
      }
    } catch (_) {}
    return result;
  }
}
