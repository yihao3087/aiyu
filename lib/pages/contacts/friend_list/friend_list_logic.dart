import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';

import '../../../core/controller/im_controller.dart';

class FriendListLogic extends GetxController {
  final imLoic = Get.find<IMController>();
  final friendList = <ISUserInfo>[].obs;
  final userIDList = <String>[];
  late StreamSubscription delSub;
  late StreamSubscription addSub;
  late StreamSubscription infoChangedSub;

  int _count = 10000;

  @override
  void onInit() {
    delSub = imLoic.friendDelSubject.listen(_delFriend);
    addSub = imLoic.friendAddSubject.listen(_addFriend);
    infoChangedSub = imLoic.friendInfoChangedSubject.listen(_friendInfoChanged);
    imLoic.onBlacklistAdd = _delFriend;
    imLoic.onBlacklistDeleted = _addFriend;
    super.onInit();
  }

  @override
  void onReady() {
    _getFriendList();
    super.onReady();
  }

  @override
  void onClose() {
    delSub.cancel();
    addSub.cancel();
    infoChangedSub.cancel();
    super.onClose();
  }

  _getFriendList() async {
    List<FriendInfo> list = [];
    while (true) {
      List<FriendInfo> temp;
      try {
        temp = await OpenIM.iMManager.friendshipManager.getFriendListPage(
          offset: list.length,
          count: _count,
          filterBlack: true,
        );
      } on PlatformException catch (e) {
        if (_isFriendDataMissing(e)) {
          Logger.print('friend list empty: ${e.message}');
          final fallback = await _loadFullFriendList();
          Logger.print('friend list fallback result: ${fallback.length}');
          list
            ..clear()
            ..addAll(fallback);
          break;
        }
        if (e.code == '10006') {
          await imLoic.ensureInitialized();
          continue;
        }
        rethrow;
      }
      list.addAll(temp);
      if (temp.length < _count) {
        break;
      }
      _count = 1000;
    }

    final result = list.map((e) {
      userIDList.add(e.userID!);

      return ISUserInfo.fromJson(e.toJson());
    }).toList();

    final convertResult = IMUtils.convertToAZList(result);

    onUserIDList(userIDList);
    friendList.assignAll(convertResult.cast<ISUserInfo>());
  }

  void onUserIDList(List<String> userIDList) {}

  _addFriend(dynamic user) {
    if (user is FriendInfo || user is BlacklistInfo) {
      _addUser(user.toJson());
    }
  }

  _delFriend(dynamic user) {
    if (user is FriendInfo || user is BlacklistInfo) {
      friendList.removeWhere((e) => e.userID == user.userID);
    }
  }

  _friendInfoChanged(FriendInfo user) {
    friendList.removeWhere((e) => e.userID == user.userID);
    _addUser(user.toJson());
  }

  void _addUser(Map<String, dynamic> json) {
    final info = ISUserInfo.fromJson(json);
    friendList.add(IMUtils.setAzPinyinAndTag(info) as ISUserInfo);

    SuspensionUtil.sortListBySuspensionTag(friendList);

    SuspensionUtil.setShowSuspensionStatus(friendList);
  }

  bool _isFriendDataMissing(PlatformException e) {
    if (e.code == '10005' || e.code == '1004') {
      return true;
    }
    final message = '${e.message ?? ''}${e.details ?? ''}';
    return message.contains('RecordNotFound');
  }

  Future<List<FriendInfo>> _loadFullFriendList() async {
    try {
      final full = await IMUtils.runWithImReady(
          () => OpenIM.iMManager.friendshipManager.getFriendList());
      Logger.print('friend list fallback fetch success: ${full.length}');
      return full;
    } catch (e) {
      Logger.print('friend list fallback failed: $e');
      return <FriendInfo>[];
    }
  }

  void viewFriendInfo(ISUserInfo info) => AppNavigator.startUserProfilePane(
        userID: info.userID!,
        nickname: info.nickname,
        faceURL: info.faceURL,
      );
}
