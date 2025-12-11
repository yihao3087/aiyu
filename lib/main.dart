import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openim_common/openim_common.dart';

import 'config/agora_config.dart';
import 'app.dart';

void main() {
  // 提前校验语音服务配置，缺失直接终止，避免运行期才暴露问题。
  AgoraConfig.assertConfigured();

  runZonedGuarded(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_shouldIgnoreError(details.exception)) {
        return;
      }
      FlutterError.presentError(details);
      Logger.print('FlutterError: ${details.exception.toString()}, ${details.stack.toString()}');
    };

    Config.init(() => runApp(const ChatApp()));
  }, (error, stackTrace) {
    if (_shouldIgnoreError(error)) {
      return;
    }
    Logger.print('FlutterError: ${error.toString()}, ${stackTrace.toString()}', onlyConsole: true);
  });
}

bool _shouldIgnoreError(Object? error) {
  if (error is PlatformException && error.code == '10006') {
    return true;
  }
  return false;
}
