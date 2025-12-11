/// Agora 语音通话配置。
///
/// 敏感参数通过 `--dart-define` 注入，避免写死在仓库中：
/// ```
/// flutter run --dart-define=AGORA_APP_ID=<appId> --dart-define=AGORA_TOKEN_SERVER=https://example/token
/// ```
class AgoraConfig {
  // 若不想在构建命令传参，可直接填入固定值；仍可被 --dart-define 覆盖
  static const String _hardcodedAppId = 'cf050808bcfb45429dd78cd42efdc596';
  static const String _hardcodedTokenServer = 'https://im.zucuzu.com/rtc/token';

  static const String _agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: _hardcodedAppId,
  );
  static const String _agoraTokenServer = String.fromEnvironment(
    'AGORA_TOKEN_SERVER',
    defaultValue: _hardcodedTokenServer,
  );

  /// 是否已配置必要参数
  static bool get isConfigured =>
      _agoraAppId.trim().isNotEmpty && _agoraTokenServer.trim().isNotEmpty;

  /// 没配置就直接抛出异常，防止运行期才发现语音不可用
  static void assertConfigured() {
    if (!isConfigured) {
      throw StateError(
        'AGORA_APP_ID 或 AGORA_TOKEN_SERVER 未配置。请在 flutter run/build 时通过 --dart-define 提供，'
        '示例：--dart-define=AGORA_APP_ID=<appId> --dart-define=AGORA_TOKEN_SERVER=https://example/token',
      );
    }
  }

  static String get agoraAppId => _require(_agoraAppId, 'AGORA_APP_ID');

  static String get agoraTokenServer => _require(_agoraTokenServer, 'AGORA_TOKEN_SERVER');

  static const int defaultTokenExpireSeconds = 3600;

  static String _require(String value, String envKey) {
    if (value.isEmpty) {
      throw StateError('$envKey 未配置，请通过 --dart-define 注入');
    }
    return value;
  }
}
