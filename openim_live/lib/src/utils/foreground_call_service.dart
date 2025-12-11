import 'package:flutter/services.dart';

class ForegroundCallService {
  ForegroundCallService._();

  static const _channel = MethodChannel('call_service_channel');
  static Future<void> Function()? _hangupHandler;

  static Future<void> start({
    required String peerName,
    String? avatarUrl,
    required int startTs,
    String? status,
    bool isCalling = false,
  }) async {
    try {
      await _channel.invokeMethod('startCallService', {
        'peerName': peerName,
        if (avatarUrl != null) 'avatar': avatarUrl,
        'startTs': startTs,
        if (status != null) 'status': status,
        'isCalling': isCalling,
      });
      _ensureHandler();
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopCallService');
    } catch (_) {}
  }

  static void registerNotificationHangupHandler(Future<void> Function() handler) {
    _hangupHandler = handler;
    _ensureHandler();
  }

  static void clearNotificationHangupHandler() {
    _hangupHandler = null;
  }

  static void _ensureHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationHangup') {
        final handler = _hangupHandler;
        if (handler != null) {
          await handler();
        }
      }
      return null;
    });
  }
}
