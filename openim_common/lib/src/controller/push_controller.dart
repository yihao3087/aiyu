import 'dart:async';
import 'dart:io';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:getuiflut/getuiflut.dart';
import 'package:openim_common/openim_common.dart';

const String _getuiAppID = String.fromEnvironment('GETUI_APP_ID', defaultValue: '');
const String _getuiAppKey = String.fromEnvironment('GETUI_APP_KEY', defaultValue: '');
const String _getuiAppSecret = String.fromEnvironment('GETUI_APP_SECRET', defaultValue: '');

bool get _hasGetuiCredential =>
    _getuiAppID.isNotEmpty && _getuiAppKey.isNotEmpty && _getuiAppSecret.isNotEmpty;

bool get _supportedPlatform => Platform.isAndroid || Platform.isIOS;

class PushController extends GetxService {
  static PushController get _instance => Get.find<PushController>();

  final Getuiflut _getui = Getuiflut();
  bool _initialized = false;
  String? _currentAlias;
  String? _currentClientId;
  String? _lastUploadedClientId;

  bool get _enabled => _supportedPlatform && _hasGetuiCredential;

  static Future<void> login(String alias) async {
    final controller = _instance;
    if (!controller._enabled) {
      Logger.print('PushController disabled, skip login');
      return;
    }
    await controller._loginWithGetui(alias);
  }

  static Future<void> logout() async {
    final controller = _instance;
    if (!controller._enabled) {
      return;
    }
    await controller._logoutGetui();
  }

  Future<void> _loginWithGetui(String alias) async {
    _currentAlias = alias;
    await _ensureGetuiInitialized();
    await _bindAlias();
    if (_currentClientId == null || _currentClientId!.isEmpty) {
      try {
        final cid = await _getui.getClientId;
        if (cid.isNotEmpty) {
          _currentClientId = cid;
        }
      } catch (e) {
        Logger.print('getui fetch clientId failed: $e');
      }
    }
    await _syncClientId();
  }

  Future<void> _logoutGetui() async {
    if (_currentAlias != null) {
      try {
        final sn = DateTime.now().millisecondsSinceEpoch.toString();
        _getui.unbindAlias(_currentAlias!, sn, true);
      } catch (e) {
        Logger.print('getui unbind alias failed: $e');
      }
    }
    _currentAlias = null;
    _currentClientId = null;
    _lastUploadedClientId = null;
  }

  Future<void> _ensureGetuiInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _getui.addEventHandler(
      onReceiveClientId: (String cid) async {
        Logger.print('getui clientId received');
        _currentClientId = cid;
        await _bindAlias();
        await _syncClientId();
      },
      onNotificationMessageArrived: (Map<String, dynamic> message) async {
        Logger.print('getui notification arrived: $message');
      },
      onNotificationMessageClicked: (Map<String, dynamic> message) async {
        Logger.print('getui notification clicked: $message');
      },
      onTransmitUserMessageReceive: (Map<String, dynamic> message) async {
        Logger.print('getui transmit message: $message');
      },
      onReceiveOnlineState: (String online) async {
        Logger.print('getui online state: $online');
      },
      onRegisterDeviceToken: (String token) async {
        Logger.print('APNs device token received');
      },
      onReceivePayload: (Map<String, dynamic> payload) async {
        Logger.print('getui payload: $payload');
      },
      onReceiveNotificationResponse: (Map<String, dynamic> message) async {
        Logger.print('getui notification response: $message');
      },
      onAppLinkPayload: (String message) async {
        Logger.print('getui app link payload: $message');
      },
      onPushModeResult: (Map<String, dynamic> result) async {
        Logger.print('getui push mode result: $result');
      },
      onSetTagResult: (Map<String, dynamic> result) async {
        Logger.print('getui set tag result: $result');
      },
      onAliasResult: (Map<String, dynamic> result) async {
        Logger.print('getui alias result: $result');
      },
      onQueryTagResult: (Map<String, dynamic> result) async {
        Logger.print('getui query tag result: $result');
      },
      onWillPresentNotification: (Map<String, dynamic> message) async {
        Logger.print('getui will present notification: $message');
      },
      onOpenSettingsForNotification: (Map<String, dynamic> message) async {
        Logger.print('getui open settings notification: $message');
      },
      onGrantAuthorization: (String granted) async {
        Logger.print('getui authorization status: $granted');
      },
      onLiveActivityResult: (Map<String, dynamic> result) async {
        Logger.print('getui live activity result: $result');
      },
      onRegisterPushToStartTokenResult: (Map<String, dynamic> result) async {
        Logger.print('getui push-to-start token updated');
      },
    );

    if (Platform.isAndroid) {
      _getui.initGetuiSdk;
      _getui.onActivityCreate();
    } else if (Platform.isIOS) {
      _getui.registerRemoteNotification();
    }
    if (_hasGetuiCredential) {
      _getui.startSdk(appId: _getuiAppID, appKey: _getuiAppKey, appSecret: _getuiAppSecret);
    } else {
      Logger.print('Getui credentials missing, push disabled');
    }
  }

  Future<void> _bindAlias() async {
    if (_currentAlias == null) return;
    try {
      final sn = DateTime.now().millisecondsSinceEpoch.toString();
      _getui.bindAlias(_currentAlias!, sn);
    } catch (e) {
      Logger.print('getui bind alias failed: $e');
    }
  }

  Future<void> _syncClientId() async {
    if (_currentClientId == null || _currentClientId == _lastUploadedClientId) {
      return;
    }
    if (!Logger().sdkIsInited) {
      Logger.print('getui clientId ready but sdk not initialized yet, postpone sync');
      return;
    }

    try {
      await OpenIM.iMManager.updateFcmToken(
        fcmToken: _currentClientId!,
        expireTime: DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch,
      );
      _lastUploadedClientId = _currentClientId;
      Logger.print('getui clientId synced to server');
    } catch (e) {
      Logger.print('sync getui clientId failed: $e');
    }
  }
}
