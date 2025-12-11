import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../../core/controller/im_controller.dart';
import '../../../core/services/device_auth_service.dart';
import '../../conversation/conversation_logic.dart';
import '../../../routes/app_navigator.dart';

class SetSelfInfoLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final nicknameCtrl = TextEditingController();
  final nickname = ''.obs;
  final faceURL = ''.obs;
  final nicknameError = RxnString();
  bool _nicknameClearedOnce = false;
  List<ConversationInfo>? _conversations;

  @override
  void onInit() {
    final user = imLogic.userInfo.value;
    nicknameCtrl.text = '';
    nickname.value = '';
    faceURL.value = user.faceURL ?? '';
    _conversations = Get.arguments?['conversations'];
    nicknameCtrl.addListener(() {
      nickname.value = nicknameCtrl.text.trim();
      nicknameError.value = null;
    });
    super.onInit();
  }

  @override
  void onClose() {
    nicknameCtrl.dispose();
    super.onClose();
  }

  Future<void> pickAvatar() async {
    try {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        Get.context!,
        pickerConfig: const AssetPickerConfig(
          requestType: RequestType.image,
          maxAssets: 1,
        ),
      );
      final file = await assets?.firstOrNull?.file;
      if (file == null) return;
      final map = await IMViews.uCropPic(file.path);
      final url = map['url'] as String?;
      if (url != null && url.isNotEmpty) {
        faceURL.value = url;
      } else {
        IMViews.showToast(StrRes.sendFailed);
      }
    } catch (e, s) {
      Logger.print('pick avatar error: $e $s');
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  void onNicknameTap() {
    if (_nicknameClearedOnce) return;
    _nicknameClearedOnce = true;
    nicknameCtrl.clear();
  }

  bool _isNicknameValid(String name) {
    if (name.trim().isEmpty) {
      nicknameError.value = StrRes.plsEnterYourNickname;
      return false;
    }
    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(name);
    if (!hasChinese) {
      nicknameError.value = StrRes.nicknameNeedChinese;
      return false;
    }
    return true;
  }

  Future<void> submit() async {
    final name = nickname.value.trim();
    if (faceURL.value.isEmpty) {
      IMViews.showToast(StrRes.pleaseSetAvatar);
      return;
    }
    if (!_isNicknameValid(name)) {
      IMViews.showToast(nicknameError.value!);
      return;
    }
    await LoadingView.singleton.wrap(asyncFunction: () async {
      await Apis.updateUserInfo(
        userID: imLogic.userInfo.value.userID!,
        nickname: name,
        faceURL: faceURL.value.isNotEmpty ? faceURL.value : null,
      );
      imLogic.userInfo.update((val) {
        val?.nickname = name;
        if (faceURL.value.isNotEmpty) {
          val?.faceURL = faceURL.value;
        }
      });
      await DeviceAuthService.markProfileCompleted();
    });
    final conversations =
        _conversations ?? await ConversationLogic.getConversationFirstPage();
    AppNavigator.startSplashToMain(
        isAutoLogin: true, conversations: conversations);
  }
}