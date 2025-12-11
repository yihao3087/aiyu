import 'dart:convert';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

void main() {
  final raw = {
    "clientMsgID": "c35041b4-d2c8-4c8c-b5f8-4d79990a59e1",
    "serverMsgID": "1731844515000450",
    "groupID": "2865876395",
    "contentType": 110,
    "content": "{\"customType\":920,\"data\":{\"text\":\"今日福利...\\n有意向的联系客服\",\"media\":[{\"type\":\"image\",\"url\":\"https://im.zucuzu.com/im-minio-api/telegram-bridge/telegram/1731844514_pic.jpg\",\"thumbnail\":\"https://im.zucuzu.com/im-minio-api/telegram-bridge/telegram/1731844514_pic_thumb.jpg\",\"width\":960,\"height\":1280}],\"layout\":[\"media\",\"text\"]}}",
    "sendID": "admin",
    "senderNickname": "客服",
    "senderFaceURL": "",
    "senderPlatformID": 1,
    "sessionType": 3,
    "sendTime": 1731844514123,
    "seq": 519332,
    "status": 2,
    "options": {
      "history": true,
      "persistent": true,
      "unreadCount": true,
      "offlinePush": true
    },
    "offlinePushInfo": {
      "title": "客服",
      "desc": "有意向的联系客服",
      "ex": "{\"source\":\"telegram\"}"
    },
    "ex": "{\"source\":\"telegram\"}"
  };
  final merged = Map<String, dynamic>.from(raw);
  final content = merged['content'] as String;
  final normalized = content;
  final message = Message.fromJson(merged);
  message.customElem ??= CustomElem();
  message.customElem!.data = normalized;
  final result = IMUtils.parseCustomMessage(message);
  print('parseCustomMessage -> ' + jsonEncode(result));
  final digest = IMUtils.messageDigest(message);
  print('messageDigest -> ' + digest);
}
