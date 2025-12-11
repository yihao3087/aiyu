import 'dart:io';

import 'package:flutter/services.dart';

/// 与原生前台 Service 交互，用于在 Android 后台保持长连接。
class BackgroundConnectionService {
  BackgroundConnectionService._();

  static const _channel = MethodChannel('connection_service_channel');

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startConnectionService');
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopConnectionService');
    } catch (_) {}
  }
}
