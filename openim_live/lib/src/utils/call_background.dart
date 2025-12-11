import 'dart:io';

import 'package:openim_common/openim_common.dart';

class CallBackgroundManager {
  CallBackgroundManager._();

  static Future<void> start({String? peerName}) async {
    if (!Platform.isAndroid) return;
    // 仅确保通知权限已开启，交由系统通知提示来电，不再启动麦克风前台服务。
    await Permissions.notification();
  }

  static Future<void> stop() async {
    // 无前台服务可停止，此处留空即可。
  }
}
