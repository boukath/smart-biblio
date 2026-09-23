import 'package:flutter/services.dart';

class WindowService {
  static const MethodChannel _channel = MethodChannel('smart_biblio/window');

  static Future<bool> isFullScreen() async {
    try {
      final res = await _channel.invokeMethod<bool>('isFullScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setFullScreen(bool enable) async {
    try {
      final res = await _channel.invokeMethod<bool>('setFullScreen', enable);
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleFullScreen() async {
    try {
      final res = await _channel.invokeMethod<bool>('toggleFullScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
