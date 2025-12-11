import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../core/controller/app_controller.dart';
import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../../routes/app_navigator.dart';

class HomeLogic extends SuperController {
  final pushLogic = Get.find<PushController>();
  final imLogic = Get.find<IMController>();
  final cacheLogic = Get.find<CacheController>();
  final initLogic = Get.find<AppController>();
  final index = 0.obs;
  final unreadMsgCount = 0.obs;
  final unhandledFriendApplicationCount = 0.obs;
  final unhandledGroupApplicationCount = 0.obs;
  final unhandledCount = 0.obs;
  var conversationsAtFirstPage = <ConversationInfo>[];

  switchTab(index) {
    this.index.value = index;
  }

  _getUnreadMsgCount() async {
    try {
      final count = await IMUtils.runWithImReady(
          () => OpenIM.iMManager.conversationManager.getTotalUnreadMsgCount());
      unreadMsgCount.value = int.tryParse(count) ?? 0;
      initLogic.showBadge(unreadMsgCount.value);
    } on PlatformException catch (e) {
      Logger.print('get unread count failed: $e');
    }
  }

  void getUnhandledFriendApplicationCount() async {
    try {
      var i = 0;
      var list = await IMUtils.runWithImReady(
          () => OpenIM.iMManager.friendshipManager.getFriendApplicationListAsRecipient());
      var haveReadList = DataSp.getHaveReadUnHandleFriendApplication();
      haveReadList ??= <String>[];
      for (var info in list) {
        var id = IMUtils.buildFriendApplicationID(info);
        if (!haveReadList.contains(id)) {
          if (info.handleResult == 0) i++;
        }
      }
      unhandledFriendApplicationCount.value = i;
      unhandledCount.value = unhandledGroupApplicationCount.value + i;
    } on PlatformException catch (e) {
      if (!IMUtils.isSdkNotInitError(e)) {
        Logger.print('get friend application count failed: $e');
      }
    }
  }

  void getUnhandledGroupApplicationCount() async {
    try {
      var i = 0;
      var list = await IMUtils.runWithImReady(
          () => OpenIM.iMManager.groupManager.getGroupApplicationListAsRecipient());
      var haveReadList = DataSp.getHaveReadUnHandleGroupApplication();
      haveReadList ??= <String>[];
      for (var info in list) {
        var id = IMUtils.buildGroupApplicationID(info);
        if (!haveReadList.contains(id)) {
          if (info.handleResult == 0) i++;
        }
      }
      unhandledGroupApplicationCount.value = i;
      unhandledCount.value = unhandledFriendApplicationCount.value + i;
    } on PlatformException catch (e) {
      if (!IMUtils.isSdkNotInitError(e)) {
        Logger.print('get group application count failed: $e');
      }
    }
  }

  @override
  void onInit() {
    if (Get.arguments != null) {
      conversationsAtFirstPage = Get.arguments['conversations'] ?? [];
    }
    imLogic.unreadMsgCountEventSubject.listen((value) {
      unreadMsgCount.value = value;
    });
    imLogic.friendApplicationChangedSubject.listen((value) {
      getUnhandledFriendApplicationCount();
    });
    imLogic.groupApplicationChangedSubject.listen((value) {
      getUnhandledGroupApplicationCount();
    });

    imLogic.imSdkStatusPublishSubject.listen((value) {
      if (value.status == IMSdkStatus.syncStart) {
        _getRTCInvitationStart();
      }
    });

    Apis.kickoffController.stream.listen((event) {
      Future(() async {
        await DataSp.removeLoginCertificate();
        await PushController.logout();
        AppNavigator.startLogin();
      });
    });
    super.onInit();
  }

  @override
  void onReady() {
    _getRTCInvitationStart();
    _getUnreadMsgCount();
    getUnhandledFriendApplicationCount();
    getUnhandledGroupApplicationCount();
    cacheLogic.initCallRecords();
    super.onReady();
  }

  @override
  void onDetached() {}

  @override
  void onInactive() {}

  @override
  void onPaused() {}

  @override
  void onResumed() {}

  void _getRTCInvitationStart() async {}

  @override
  void onHidden() {}
}
