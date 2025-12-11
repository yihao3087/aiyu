import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class FloatingWindowBridge {
  FloatingWindowBridge._();

  static const MethodChannel _channel = MethodChannel('call_service_channel');
  static final StreamController<void> _tapController = StreamController<void>.broadcast();
  static bool _handlerRegistered = false;

  static Stream<void> get onFloatingWindowTapped {
    _ensureHandler();
    return _tapController.stream;
  }

  static void _ensureHandler() {
    if (_handlerRegistered) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'floatingWindowTapped') {
        _tapController.add(null);
      }
    });
    _handlerRegistered = true;
  }

  static Future<void> show({
    required String peerName,
    String? avatarUrl,
    String? status,
  }) async {
    if (!Platform.isAndroid) return;
    _ensureHandler();
    try {
      await _channel.invokeMethod('showFloatingWindow', {
        'peerName': peerName,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar': avatarUrl,
        if (status != null && status.isNotEmpty) 'status': status,
      });
    } catch (_) {}
  }

  static Future<void> hide() async {
    if (!Platform.isAndroid) return;
    _ensureHandler();
    try {
      await _channel.invokeMethod('hideFloatingWindow');
    } catch (_) {}
  }
}
