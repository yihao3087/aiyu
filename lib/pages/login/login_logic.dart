import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../core/controller/im_controller.dart';
import '../../core/services/background_connection_service.dart';
import '../../core/services/auto_login_service.dart';
import '../../core/services/device_auth_service.dart';
import '../../routes/app_navigator.dart';
import '../conversation/conversation_logic.dart';

class LoginLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final autoLoginService = Get.find<AutoLoginService>();
  final accountCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final enabled = false.obs;

  FocusNode? accountFocus = FocusNode();
  FocusNode? pwdFocus = FocusNode();

  RxBool get autoLoginBusy => autoLoginService.autoLoginBusy;

  @override
  void onInit() {
    _initData();
    accountCtrl.addListener(_onChanged);
    pwdCtrl.addListener(_onChanged);
    super.onInit();
  }

  @override
  void onClose() {
    accountCtrl.dispose();
    pwdCtrl.dispose();
    accountFocus?.dispose();
    pwdFocus?.dispose();
    super.onClose();
  }

  void _initData() {
    var map = DataSp.getLoginAccount();
    if (map is Map) {
      final account = map['account'];
      if (account is String && account.isNotEmpty) {
        accountCtrl.text = account;
      }
    }
  }

  void _onChanged() {
    enabled.value = accountCtrl.text.trim().isNotEmpty && pwdCtrl.text.trim().isNotEmpty;
  }

  void login() {
    final account = accountCtrl.text.trim();
    final password = pwdCtrl.text.trim();
    if (account.isEmpty || password.isEmpty) {
      return;
    }
    LoadingView.singleton.wrap(asyncFunction: () async {
      final cert = await _login(account: account, password: password);
      if (cert == null) return;
      await _ensureProfileFlag(cert);
      await BackgroundConnectionService.start();
      final result = await ConversationLogic.getConversationFirstPage();
      Get.find<CacheController>().resetCache();
      AppNavigator.startMain(conversations: result);
    });
  }

  Future<LoginCertificate?> _login({required String account, required String password}) async {
    try {
      final data = await Apis.login(
        account: account,
        password: password,
      );
      await DataSp.putLoginCertificate(data);
      await DataSp.putDeviceProfileStatus(data.needProfile);
      await DataSp.putLoginAccount({'account': account});
      await DeviceAuthService.saveCredentials(account, password);
      Logger.print('login success: ${data.userID}');
      await imLogic.login(data.userID, data.imToken);
      Logger.print('im login success');
      await PushController.login(data.userID);
      Logger.print('push login success');
      return data;
    } catch (e, s) {
      Logger.print('login e: $e  s:$s');
    }
    return null;
  }

  void registerNow() => AppNavigator.startRegister();

  Future<void> _ensureProfileFlag(LoginCertificate cert) async {
    final localNeed = DataSp.needCompleteProfile;
    final needProfile = cert.needProfile && localNeed;
    Logger.print(
      'login needProfile check => serverNeed:${cert.needProfile} localNeed:$localNeed finalNeed:$needProfile',
    );
    if (!needProfile) return;
    await DeviceAuthService.markProfileCompleted();
    Logger.print('login force markProfileCompleted to skip profile page');
  }
}
