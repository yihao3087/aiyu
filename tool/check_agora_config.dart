import 'dart:io';

void main() {
  final appId = _read('AGORA_APP_ID');
  final tokenServer = _read('AGORA_TOKEN_SERVER');

  _require(appId.isNotEmpty, 'AGORA_APP_ID 未设置');
  _require(tokenServer.isNotEmpty, 'AGORA_TOKEN_SERVER 未设置');

  final uri = Uri.tryParse(tokenServer);
  _require(uri != null && uri.hasScheme && uri.isAbsolute, 'AGORA_TOKEN_SERVER 必须是有效的 URL');
  _require(uri!.scheme == 'https', 'AGORA_TOKEN_SERVER 必须使用 https');

  stdout.writeln('✅ Agora 配置检查通过');
}

String _read(String key) => Platform.environment[key]?.trim() ?? '';

void _require(bool cond, String message) {
  if (!cond) {
    stderr.writeln('❌ $message');
    exit(1);
  }
}
