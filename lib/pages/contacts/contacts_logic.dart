import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';

import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../home/home_logic.dart';
import 'select_contacts/select_contacts_logic.dart';

class ContactsLogic extends GetxController
    implements ViewUserProfileBridge, SelectContactsBridge {
  final imLogic = Get.find<IMController>();
  final homeLogic = Get.find<HomeLogic>();

  final friendApplicationList = <UserInfo>[];
  final friendList = <ISUserInfo>[].obs;
  final userIDList = <String>[];
  late StreamSubscription _friendDelSub;
  late StreamSubscription _friendAddSub;
  late StreamSubscription _friendInfoChangedSub;
  late StreamSubscription _imSdkStatusSub;
  bool _isFetchingFriends = false;
  bool _pendingSyncRefresh = false;

  int _friendPageSize = 10000;

  int get friendApplicationCount =>
      homeLogic.unhandledFriendApplicationCount.value;

  @override
  void onInit() {
    super.onInit();
    PackageBridge.selectContactsBridge = this;
    PackageBridge.viewUserProfileBridge = this;
    _initFriendObservers();
    _initSyncStatusListener();
    _getFriendList();
  }

  void _initFriendObservers() {
    _friendDelSub = imLogic.friendDelSubject.listen(_delFriend);
    _friendAddSub = imLogic.friendAddSubject.listen(_addFriend);
    _friendInfoChangedSub =
        imLogic.friendInfoChangedSubject.listen(_friendInfoChanged);
    imLogic.onBlacklistAdd = _delFriend;
    imLogic.onBlacklistDeleted = _addFriend;
  }

  @override
  void onClose() {
    PackageBridge.selectContactsBridge = null;
    PackageBridge.viewUserProfileBridge = null;
    _friendDelSub.cancel();
    _friendAddSub.cancel();
    _friendInfoChangedSub.cancel();
    imLogic.onBlacklistAdd = null;
    imLogic.onBlacklistDeleted = null;
    _imSdkStatusSub.cancel();
    super.onClose();
  }

  void newFriend() => AppNavigator.startFriendRequests();

  void myGroup() => AppNavigator.startGroupList();

  void searchContacts() => AppNavigator.startGlobalSearch();

  void addContacts() => AppNavigator.startAddContactsMethod();

  void _initSyncStatusListener() {
    final statuses = imLogic.imSdkStatusSubject.values;
    _pendingSyncRefresh =
        statuses.isEmpty || statuses.last.status != IMSdkStatus.syncEnded;
    _imSdkStatusSub = imLogic.imSdkStatusSubject.listen((event) {
      switch (event.status) {
        case IMSdkStatus.syncStart:
          _pendingSyncRefresh = true;
          break;
        case IMSdkStatus.syncEnded:
          final needRefresh =
              _pendingSyncRefresh || event.reInstall || friendList.isEmpty;
          _pendingSyncRefresh = false;
          if (needRefresh) {
            _getFriendList();
          }
          break;
        case IMSdkStatus.syncFailed:
          _pendingSyncRefresh = false;
          break;
        default:
          break;
      }
    });
  }

  Future<void> _getFriendList() async {
    if (_isFetchingFriends) return;
    _isFetchingFriends = true;
    try {
      List<FriendInfo> list = [];
      while (true) {
        List<FriendInfo> temp;
        try {
          temp = await OpenIM.iMManager.friendshipManager.getFriendListPage(
            offset: list.length,
            count: _friendPageSize,
            filterBlack: true,
          );
        } on PlatformException catch (e) {
          if (_isFriendDataMissing(e)) {
            Logger.print('friend list page empty: ${e.message}');
            final fallback = await _loadFullFriendList();
            Logger.print('friend list fallback result: ${fallback.length}');
            list
              ..clear()
              ..addAll(fallback);
            break;
          }
          if (e.code == '10006') {
            await imLogic.ensureInitialized();
            continue;
          }
          rethrow;
        }
        list.addAll(temp);
        if (temp.length < _friendPageSize) {
          break;
        }
        _friendPageSize = 1000;
      }

      userIDList.clear();
      final result = list.map((e) {
        userIDList.add(e.userID!);
        return ISUserInfo.fromJson(e.toJson());
      }).toList();
      final convertResult = IMUtils.convertToAZList(result);
      onUserIDList(userIDList);
      friendList.assignAll(convertResult.cast<ISUserInfo>());
    } finally {
      _isFetchingFriends = false;
    }
  }

  void onUserIDList(List<String> ids) {}

  void _addFriend(dynamic user) {
    if (user is FriendInfo || user is BlacklistInfo) {
      _addUser(user.toJson());
    }
  }

  bool _isFriendDataMissing(PlatformException e) {
    final code = e.code;
    if (code == '10005' || code == '1004') {
      return true;
    }
    final message = '${e.message ?? ''}${e.details ?? ''}';
    return message.contains('RecordNotFound');
  }

  Future<List<FriendInfo>> _loadFullFriendList() async {
    try {
      final list = await IMUtils.runWithImReady(
          () => OpenIM.iMManager.friendshipManager.getFriendList());
      Logger.print('fallback getFriendList success: ${list.length}');
      return list;
    } catch (e) {
      Logger.print('fallback getFriendList failed: $e');
      return <FriendInfo>[];
    }
  }

  void _delFriend(dynamic user) {
    if (user is FriendInfo || user is BlacklistInfo) {
      friendList.removeWhere((e) => e.userID == user.userID);
    }
  }

  void _friendInfoChanged(FriendInfo user) {
    friendList.removeWhere((e) => e.userID == user.userID);
    _addUser(user.toJson());
  }

  void _addUser(Map<String, dynamic> json) {
    final info = ISUserInfo.fromJson(json);
    friendList.add(IMUtils.setAzPinyinAndTag(info) as ISUserInfo);
    SuspensionUtil.sortListBySuspensionTag(friendList);
    SuspensionUtil.setShowSuspensionStatus(friendList);
  }

  void viewFriendInfo(ISUserInfo info) => AppNavigator.startUserProfilePane(
        userID: info.userID!,
        nickname: info.nickname,
        faceURL: info.faceURL,
      );

  @override
  Future<T?>? selectContacts<T>(
    int type, {
    List<String>? defaultCheckedIDList,
    List? checkedList,
    List<String>? excludeIDList,
    bool openSelectedSheet = false,
    String? groupID,
    String? ex,
  }) =>
      AppNavigator.startSelectContacts(
        action: SelAction.values[type],
        defaultCheckedIDList: defaultCheckedIDList,
        checkedList: checkedList,
        excludeIDList: excludeIDList,
        openSelectedSheet: openSelectedSheet,
        groupID: groupID,
        ex: ex,
      );

  @override
  viewUserProfile(String userID, String? nickname, String? faceURL,
          [String? groupID]) =>
      AppNavigator.startUserProfilePane(
        userID: userID,
        nickname: nickname,
        faceURL: faceURL,
        groupID: groupID,
      );
}
