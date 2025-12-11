class MapConfig {
  MapConfig._();

  // 内置默认值，仍可用 --dart-define 覆盖
  static const String _hardcodedWebKey = '6f42b018aec35719738b2fade8996e55';
  static const String _hardcodedAndroidKey = '367b46ecd857c856ac4b71fa60ce7403';
  static const String _hardcodedIosKey = 'c4a40ea3236ece1b8340ca157cc1f6c8';

  static const String _amapWebKey =
      String.fromEnvironment('AMAP_WEB_KEY', defaultValue: _hardcodedWebKey);
  static const String _amapAndroidKey =
      String.fromEnvironment('AMAP_ANDROID_KEY', defaultValue: _hardcodedAndroidKey);
  static const String _amapIosKey =
      String.fromEnvironment('AMAP_IOS_KEY', defaultValue: _hardcodedIosKey);

  static String get amapWebKey => _require(_amapWebKey, 'AMAP_WEB_KEY');

  static String get amapAndroidKey => _require(_amapAndroidKey, 'AMAP_ANDROID_KEY');

  static String get amapIosKey => _require(_amapIosKey, 'AMAP_IOS_KEY');

  static String? buildAmapStaticMap({
    required double latitude,
    required double longitude,
    int width = 480,
    int height = 240,
    int zoom = 16,
  }) {
    final safeWidth = width.clamp(200, 1024);
    final safeHeight = height.clamp(200, 1024);
    final safeZoom = zoom.clamp(3, 18);
    final location = '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}';
    final uri = Uri.https(
      'restapi.amap.com',
      '/v3/staticmap',
      {
        'key': amapWebKey,
        'location': location,
        'zoom': '$safeZoom',
        'size': '$safeWidth*$safeHeight',
        'markers': 'mid,0x2E9BFF,:$location',
        'scale': '2',
      },
    );
    return uri.toString();
  }

  static String _require(String value, String envKey) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw StateError('$envKey 未配置，请通过 --dart-define 注入');
    }
    return trimmed;
  }
}
