import 'dart:io';

import 'package:flutter/services.dart';

class DeviceIdProvider {
  static const _channel = MethodChannel('device_id_channel');

  static Future<String> getDeviceHash() async {
    final hash = await _channel.invokeMethod<String>('getDeviceHash');
    if (hash == null || hash.trim().isEmpty) {
      throw PlatformException(
        code: 'device_hash_unavailable',
        message: '无法获取唯一设备标识，请检查设备权限后重试',
      );
    }
    return hash;
  }

  static String get platformLabel => Platform.isIOS ? 'ios' : 'android';
}
