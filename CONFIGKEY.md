
# Common Function Configuration Guide

- [Offline push](#offlinepush)
- [Map](#map)
- [Agora](#agora)

## Offlinepush

Currently the client only keeps the Getui integration (FCM has been fully removed in this build).

### Client configuration

#### 1. Use Getui (https://getui.com/) in mainland China

###### Configure iOS and Android in the integration guide of Getui

**iOS platform configuration:**
According to [its documentation](https://docs.getui.com/getui/mobile/ios/overview/), make the corresponding iOS configuration. Keys are now injected via `--dart-define`, for example:

```bash
flutter run \
  --dart-define=GETUI_APP_ID=your-app-id \
  --dart-define=GETUI_APP_KEY=your-app-key \
  --dart-define=GETUI_APP_SECRET=your-app-secret
```

**Android platform configuration:**
According to [its documentation](https://docs.getui.com/getui/mobile/android/overview/), make corresponding Android configurations, and pay attention to [multi-vendor](https://docs.getui.com/getui/mobile/vendor/vendor_open/) configurations. Then modify the following file contents:

- **[build.gradle](android/app/build.gradle)**

```gradle
  manifestPlaceholders = [
      GETUI_APPID     : project.findProperty("GETUI_APPID") ?: "",
      GETUI_APPKEY    : project.findProperty("GETUI_APPKEY") ?: "",
      GETUI_APPSECRET : project.findProperty("GETUI_APPSECRET") ?: "",
      XIAOMI_APP_ID   : "",
      XIAOMI_APP_KEY  : "",
      ...
  ]
```

You can also configure `GETUI_*` values through `gradle.properties`, `local.properties`, or environment variables that Gradle can read.


### Offline push banner settings

Currently, the SDK is designed to directly control the display content of the push banner by the client. When sending a message, set the input parameter [offlinePushInfo](https://github.com/openimsdk/openim-flutter-demo/blob/cc72b6d7ca5f70ca07885857beecec512f904f8c/lib/pages/chat/chat_logic.dart#L543):

```dart
  final offlinePushInfo = OfflinePushInfo(
  title: "Fill in the title",
  desc: "Fill in the description, such as the message content",
  iOSBadgeCount: true,
  );
  // If you do not customize offlinePushInfo, the title defaults to the app name, and the desc defaults to "You received a new message"
```

According to actual needs, you can enable the offline push function after completing the corresponding client and server configurations.

---

## Map

### Configuration Guide

Need to configure the corresponding AMap Key. Please refer to [AMap Document](https://lbs.amap.com/) for details. The project now expects keys to be provided via build-time variables:

- **Static map / reverse geo**: 默认内置 `6f42b018aec35719738b2fade8996e55`，可使用 `--dart-define=AMAP_WEB_KEY=xxx` 覆盖
- **Android SDK**: set `AMAP_ANDROID_KEY` through Gradle properties/environment (consumed by `manifestPlaceholders`)
- **iOS SDK**: set `AMAP_IOS_KEY` via Xcode build settings or `.xcconfig` (referenced as `$(AMAP_IOS_KEY)` in `Info.plist`)

已内置默认 Key（可用 --dart-define 覆盖）：  
- AMAP_WEB_KEY: `6f42b018aec35719738b2fade8996e55`  
- AMAP_ANDROID_KEY: `367b46ecd857c856ac4b71fa60ce7403`  
- AMAP_IOS_KEY: `c4a40ea3236ece1b8340ca157cc1f6c8`  

If you leave the Dart defines empty the bundled defaults above will be used, but you can still override them at build time when necessary.

---

## Agora

- 必填参数：`AGORA_APP_ID`、`AGORA_TOKEN_SERVER`（通过 `--dart-define` 注入）
- 打包/运行示例：
  ```bash
  flutter run \
    --dart-define=AGORA_APP_ID=your-app-id \
    --dart-define=AGORA_TOKEN_SERVER=https://your-token-server
  ```
- 构建前快速校验：使用同一套环境变量运行
  ```bash
  AGORA_APP_ID=your-app-id \
  AGORA_TOKEN_SERVER=https://your-token-server \
  dart run tool/check_agora_config.dart
  ```
  未通过会返回非零退出码，阻断构建。
