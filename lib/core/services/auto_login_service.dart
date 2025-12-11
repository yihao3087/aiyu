import 'dart:async';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim/core/services/background_connection_service.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';

import '../../pages/conversation/conversation_logic.dart';
import 'device_auth_service.dart';

class AutoLoginService extends GetxService {
  final imLogic = Get.find<IMController>();
  final cacheController = Get.find<CacheController>();
  final autoLoginBusy = false.obs;

  StreamSubscription<bool>? _initializedSub;
  Timer? _retryTimer;
  bool _autoLoginTriggered = false;
  bool _bootstrapping = false;
  int _retryCount = 0;

  static const int _maxRetries = 3;

  @override
  void onInit() {
    super.onInit();
    _listenAutoLogin();
  }

  @override
  void onClose() {
    _initializedSub?.cancel();
    _retryTimer?.cancel();
    super.onClose();
  }

  void _listenAutoLogin() {
    if (_autoLoginTriggered) return;
    if (Logger().sdkIsInited) {
      _triggerAutoLoginOnce();
      return;
    }
    _initializedSub = imLogic.initializedSubject.listen((initialized) {
      if (initialized) {
        _initializedSub?.cancel();
        _triggerAutoLoginOnce();
      }
    });
  }

  void _triggerAutoLoginOnce() {
    if (_autoLoginTriggered) return;
    _autoLoginTriggered = true;
    _autoLogin();
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    _retryCount += 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: (_retryCount + 1) * 2), _autoLogin);
  }

  Future<void> _autoLogin() async {
    if (_bootstrapping) return;
    _bootstrapping = true;
    autoLoginBusy.value = true;
    try {
      await imLogic.ensureInitialized();
      await Future.delayed(const Duration(milliseconds: 200));
      final cert = await DeviceAuthService.tryDeviceLogin();
      if (cert == null) {
        _retryTimer?.cancel();
        _retryCount = 0;
        return;
      }
      Logger.print('device auto login userID: ${cert.userID}');
      await imLogic.login(cert.userID, cert.imToken);
      await PushController.login(cert.userID);
      List<ConversationInfo> conversations = const [];
      try {
        conversations = await ConversationLogic.getConversationFirstPage();
      } catch (e) {
        Logger.print('fetch conversation page failed: $e');
      }
      final localNeedProfile = DataSp.needCompleteProfile;
      final needProfile = cert.needProfile && localNeedProfile;
      if (needProfile) {
        await DeviceAuthService.markProfileCompleted();
      }
      await BackgroundConnectionService.start();
      cacheController.resetCache();
      AppNavigator.startMain(isAutoLogin: true, conversations: conversations);
      _retryCount = 0;
      _retryTimer?.cancel();
    } catch (e, s) {
      Logger.print('auto login failed: $e\n$s');
      _scheduleRetry();
    } finally {
      autoLoginBusy.value = false;
      _bootstrapping = false;
    }
  }
}
