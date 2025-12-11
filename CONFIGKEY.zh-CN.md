# 常见功能配置指南

- [离线推送](#离线推送)
- [地图功能](#地图功能)

## 离线推送

当前客户端仅保留个推（Getui）通道，FCM 已在本版本中全部移除。

### 客户端配置

#### 1. 中国大陆地区使用 [个推 Getui](https://getui.com/)

- **iOS 平台**：参考[官方文档](https://docs.getui.com/getui/mobile/ios/overview/)完成原生配置，通过 `--dart-define` 注入秘钥，例如：

  ```bash
  flutter run \
    --dart-define=GETUI_APP_ID=your-app-id \
    --dart-define=GETUI_APP_KEY=your-app-key \
    --dart-define=GETUI_APP_SECRET=your-app-secret
  ```

- **Android 平台**：参考[官方文档](https://docs.getui.com/getui/mobile/android/overview/)以及[厂商通道配置指南](https://docs.getui.com/getui/mobile/vendor/vendor_open/)。项目在 `android/app/build.gradle` 中通过 `manifestPlaceholders` 读取 `GETUI_APPID/GETUI_APPKEY/GETUI_APPSECRET` 以及 `AMAP_ANDROID_KEY`，可在 `gradle.properties`、`local.properties` 或系统环境变量中设置。

### 离线推送通知内容

SDK 支持客户端在发送消息时自定义 `offlinePushInfo`（参考 `lib/pages/chat/chat_logic.dart`）；若未设置，默认提示“你收到了一条新消息”。

---

## 地图功能

需要在高德开放平台申请相应 Key，并按平台注入：

- **静态图/逆地理**：默认使用 `6f42b018aec35719738b2fade8996e55`，可通过 `--dart-define=AMAP_WEB_KEY=xxx` 覆盖
- **Android SDK**：通过 Gradle `manifestPlaceholders` 设置 `AMAP_ANDROID_KEY`
- **iOS SDK**：在 Xcode Build Settings 或 `.xcconfig` 中设置 `AMAP_IOS_KEY`，`Info.plist` 已引用 `$(AMAP_IOS_KEY)`

若未配置对应 Key，地图能力会自动降级（例如仅发送基础定位信息），不会导致应用崩溃。
