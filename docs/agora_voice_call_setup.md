# 声网（Agora）语音通话接入说明

本文档说明如何在当前项目中启用“一对一语音通话”功能，并在 Flutter 端与声网 SDK 对接。

## 1. 准备声网项目

1. 登录 [Agora 控制台](https://console.agora.io/)，创建一个 RTC 项目。
2. 记录项目的 **App ID**。如需正式上线，请切换到 “安全模式 2（App ID + App Certificate）”，并妥善保管 **App Certificate**。
3. 如果之前曾公开过证书，务必在控制台中重置，使旧证书失效。

## 2. 配置 Token 服务（推荐）

声网官方建议在服务端生成 Token。可以参考文档中提供的 `server.js` 样例执行：

```powershell
cd C:\Users\<你的用户名>\Desktop
mkdir agora-token-server
cd agora-token-server
npm init -y
npm install express cors agora-token

notepad server.js  # 将 App ID、App Certificate 替换成真实值
node server.js     # 启动服务，默认监听 http://127.0.0.1:7000/rtc/token
```

客户端请求示例：

```bash
curl http://127.0.0.1:7000/rtc/token ^
  -Method Post ^
  -Headers @{"Content-Type"="application/json"} ^
  -Body '{"channelName":"test","uid":1001,"expire":3600}'
```

> 若暂时只做本地测试，可在声网控制台将项目切换到 “安全模式 1（无需 Token）”，但 **正式上线前必须改为服务端生成 Token**。

## 3. 在客户端填写配置

打开 `lib/config/agora_config.dart`，填写真实的 App ID 与 Token 服务地址：

```dart
class AgoraConfig {
  static const String agoraAppId = '你的 App ID';
  static const String agoraTokenServer = 'http://你的服务器:7000/rtc/token';
  static const int defaultTokenExpireSeconds = 3600;
}
```

如果暂时使用 “安全模式 1”，可以将 `agoraTokenServer` 留空，并在调用时传入 `token: ''`，但请注意安全风险。

## 4. 调用语音通话页面

项目中新增了 `AgoraVoiceCallPage` 与 `AgoraVoiceCallController`：

```dart
Get.to(() => AgoraVoiceCallPage(
      channelName: 'call_${callerId}_$timestamp',
      localUid: callerId.hashCode & 0x7fffffff,
      remoteUserId: calleeId,
      onCallEnded: () {
        // TODO: 通话结束后的处理，例如发送信令
      },
    ));
```

通话前确保：

- 发起 `Permission.microphone` 申请；
- 从自己的后端获取对应频道的 Token；
- 确认双方在同一频道名下调用 `joinChannel`。

## 5. 与 OpenIM 呼叫流程对接

推荐流程：

1. A 发起通话 → 给 B 发送自定义呼叫消息，携带 `channelName`。
2. B 接收后弹出接听界面，点击接听时同样跳转到 `AgoraVoiceCallPage`。
3. 双方分别向后端请求 Token → 加入频道 → 开始通话。
4. 挂断时发送结束信令，并调用 `Navigator.pop()`。

需要悬浮窗/全屏通知等能力时，可复用项目现有的权限申请逻辑。

## 6. 常见问题

- **Token 获取失败**：检查 `AgoraConfig.agoraTokenServer` 是否填写正确，后端是否正常返回 `{"errCode":0,"data":{"token":""}}`。
- **网络异常**：确保海外/外网环境能访问声网网络；若在公司或海外网络受限，需要开启代理或使用声网内建的 TURN。
- **UID 必须为整数**：可以使用 `userId.hashCode & 0x7fffffff` 将字符串转换为正整数 UID。
- **安全性**：App Certificate 绝不能下发到客户端；所有 Token 必须由可信后端生成。

完成以上配置后，即可在项目中使用声网实现一对一语音通话。若仍有集成问题，请结合日志（`flutter run --verbose` 或 `adb logcat`）定位，并反馈具体错误信息便于排查。!
