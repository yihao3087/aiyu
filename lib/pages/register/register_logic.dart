import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:uuid/uuid.dart';

import '../../core/controller/im_controller.dart';
import '../../core/services/auto_login_service.dart';
import '../../core/services/background_connection_service.dart';
import '../../core/services/device_auth_service.dart';
import '../../routes/app_navigator.dart';
import '../conversation/conversation_logic.dart';

class RegisterLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final autoLoginService = Get.find<AutoLoginService>();
  final accountCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final avatarPath = ''.obs;
  final avatarUploadedUrl = ''.obs;
  final enabled = false.obs;
  final accountError = ''.obs;
  final pwdError = ''.obs;
  final submitted = false.obs;
  RxBool get autoLoginBusy => autoLoginService.autoLoginBusy;

  @override
  void onInit() {
    super.onInit();
    accountCtrl.addListener(_onChanged);
    pwdCtrl.addListener(_onChanged);
  }

  @override
  void onClose() {
    accountCtrl.dispose();
    pwdCtrl.dispose();
    super.onClose();
  }

  void _onChanged() {
    _validateAll();
  }

  void pickAvatar() {
    IMViews.openPhotoSheet(
      crop: true,
      toUrl: false,
      onData: (path, url) {
        final localPath = path is String ? path : (path?.toString() ?? '');
        final remoteUrl = url is String ? url : (url?.toString() ?? '');
        if (localPath.isEmpty) return;
        avatarPath.value = localPath;
        avatarUploadedUrl.value = remoteUrl;
        _onChanged();
      },
    );
  }

  void register() {
    submitted.value = true;
    _validateAll(forceEmptyErrors: true);
    if (!_checkInput()) return;
    final account = accountCtrl.text.trim();
    final password = pwdCtrl.text.trim();

    LoadingView.singleton.wrap(asyncFunction: () async {
      try {
        final data = await Apis.register(
          account: account,
          nickname: null,
          password: password,
        );
        if (IMUtils.emptyStrToNull(data.imToken) == null || IMUtils.emptyStrToNull(data.chatToken) == null) {
          AppNavigator.startLogin();
          return;
        }
        await DataSp.putLoginCertificate(data);
        await DataSp.putLoginAccount({'account': account});
        await DeviceAuthService.saveCredentials(account, password);
        await imLogic.login(data.userID, data.imToken);
        await PushController.login(data.userID);
        final serverInfo = await _refreshServerProfile(data.userID);
        await _syncProfile(userID: data.userID, nickname: serverInfo?.nickname);
        await BackgroundConnectionService.start();
        final conversations = await ConversationLogic.getConversationFirstPage();
        Get.find<CacheController>().resetCache();
        AppNavigator.startMain(conversations: conversations);
      } catch (e) {
        if (e is (int, String)) {
          final (code, msg) = e;
          if (code == 20004) {
            IMViews.showToast(StrRes.accountAlreadyExists);
            return;
          }
          if (msg.isNotEmpty) {
            IMViews.showToast(msg);
            return;
          }
        }
        rethrow;
      }
    });
  }

  void goLogin() {
    AppNavigator.startAccountLogin();
  }

  bool _checkInput() {
    if (avatarPath.value.isEmpty) {
      IMViews.showToast(StrRes.pleaseSetAvatar);
      return false;
    }
    if (accountError.value.isNotEmpty) {
      IMViews.showToast(accountError.value);
      return false;
    }
    if (pwdError.value.isNotEmpty) {
      IMViews.showToast(pwdError.value);
      return false;
    }
    return true;
  }

  Future<void> _syncProfile({required String userID, String? nickname}) async {
    try {
      if (avatarPath.value.isEmpty) {
        Logger.print('syncProfile: no avatar change, mark profile directly');
        await DeviceAuthService.markProfileCompleted();
        return;
      }
      String? url = avatarUploadedUrl.value.trim().isNotEmpty ? avatarUploadedUrl.value.trim() : null;
      url ??= await _uploadAvatar(avatarPath.value);
      if (url == null || url.isEmpty) {
        IMViews.showToast(StrRes.sendFailed);
        await DeviceAuthService.markProfileCompleted();
        return;
      }
      await Apis.updateUserInfo(
        userID: userID,
        nickname: nickname?.isNotEmpty == true ? nickname : null,
        faceURL: url,
      );
      imLogic.userInfo.update((val) {
        val?.faceURL = url;
        if (nickname != null && nickname.isNotEmpty) {
          val?.nickname = nickname;
        }
      });
      final cert = DataSp.getLoginCertificate();
      if (cert != null) {
        cert.faceURL = url;
        if (nickname != null && nickname.isNotEmpty) {
          cert.nickname = nickname;
        }
        await DataSp.putLoginCertificate(cert);
      }
      await DeviceAuthService.markProfileCompleted();
      Logger.print('syncProfile success, faceURL updated');
    } catch (e, s) {
      Logger.print('sync profile error: $e $s');
      IMViews.showToast(StrRes.networkAnomaly);
    }
  }

  Future<String?> _uploadAvatar(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    await imLogic.ensureInitialized();
    final processed = await IMUtils.compressImageAndGetFile(file, quality: 85);
    final target = processed ?? file;
    final result = await OpenIM.iMManager.uploadFile(
      id: const Uuid().v4(),
      filePath: target.path,
      fileName: target.path.split('/').last,
    );
    if (result is String) {
      final map = jsonDecode(result) as Map<String, dynamic>;
      final direct = map['url'];
      if (direct is String && direct.isNotEmpty) {
        return direct;
      }
      final nested = map['data'];
      if (nested is Map<String, dynamic>) {
        final nestedUrl = nested['url'];
        if (nestedUrl is String && nestedUrl.isNotEmpty) {
          return nestedUrl;
        }
      }
    }
    return null;
  }

  void _validateAll({bool forceEmptyErrors = false}) {
    accountError.value = _accountErrorText(forceEmptyErrors);
    pwdError.value = _pwdErrorText(forceEmptyErrors);
    enabled.value = avatarPath.value.isNotEmpty &&
        accountError.value.isEmpty &&
        pwdError.value.isEmpty &&
        accountCtrl.text.trim().isNotEmpty &&
        pwdCtrl.text.isNotEmpty;
  }

  String _accountErrorText(bool forceEmpty) {
    final account = accountCtrl.text.trim();
    if (account.isEmpty) {
      return forceEmpty ? StrRes.plsEnterRightAccount : '';
    }
    if (account.length < 4) {
      return StrRes.accountTooShort;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(account)) {
      return StrRes.accountFormatHint;
    }
    return '';
  }

  String _pwdErrorText(bool forceEmpty) {
    final pwd = pwdCtrl.text;
    if (pwd.isEmpty) {
      return forceEmpty ? StrRes.loginPwdFormat : '';
    }
    if (!IMUtils.isValidPassword(pwd)) {
      return StrRes.loginPwdFormat;
    }
    return '';
  }

  Future<PublicUserInfo?> _refreshServerProfile(String userID) async {
    try {
      final list = await OpenIM.iMManager.userManager.getUsersInfo(userIDList: [userID]);
      if (list.isNotEmpty) {
        final info = list.first;
        imLogic.userInfo.update((val) {
          val?.nickname = info.nickname;
          val?.faceURL = info.faceURL;
        });
        final cert = DataSp.getLoginCertificate();
        if (cert != null) {
          cert.nickname = info.nickname;
          cert.faceURL = info.faceURL;
          await DataSp.putLoginCertificate(cert);
        }
        return info;
      }
    } catch (e, s) {
      Logger.print('refresh profile error: $e $s');
    }
    return null;
  }

}
