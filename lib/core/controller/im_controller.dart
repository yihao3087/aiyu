import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/openim_live.dart';

import '../im_callback.dart';
import '../services/background_connection_service.dart';

class IMController extends GetxController with IMCallback, OpenIMLive {
  final Completer<void> _initCompleter = Completer<void>();
  bool _initInProgress = false;
  late Rx<UserFullInfo> userInfo;
  late String atAllTag;

  @override
  void onClose() {
    if (!_initCompleter.isCompleted) {
      _initCompleter.completeError(StateError('IMController disposed before SDK initialization finished'));
    }
    super.close();
    onCloseLive();
    super.onClose();
  }

  @override
  void onInit() async {
    super.onInit();
    onInitLive();
    initOpenIM();
  }

  Future<void> ensureInitialized() => _initCompleter.future;

  void initOpenIM() async {
    if (_initCompleter.isCompleted || _initInProgress) {
      return;
    }
    _initInProgress = true;
    try {
      final initialized = await OpenIM.iMManager.initSDK(
        platformID: IMUtils.getPlatform(),
        apiAddr: Config.imApiUrl,
        wsAddr: Config.imWsUrl,
        dataDir: Config.cachePath,
        logLevel: Config.logLevel,
        logFilePath: Config.cachePath,
        listener: OnConnectListener(
          onConnecting: () {
            imSdkStatus(IMSdkStatus.connecting);
          },
          onConnectFailed: (code, error) {
            imSdkStatus(IMSdkStatus.connectionFailed);
          },
          onConnectSuccess: () {
            imSdkStatus(IMSdkStatus.connectionSucceeded);
          },
          onKickedOffline: kickedOffline,
          onUserTokenExpired: kickedOffline,
          onUserTokenInvalid: userTokenInvalid,
        ),
      );

      OpenIM.iMManager
        ..setUploadLogsListener(OnUploadLogsListener(onUploadProgress: uploadLogsProgress))
        ..userManager.setUserListener(OnUserListener(
            onSelfInfoUpdated: (u) {
              selfInfoUpdated(u);

              userInfo.update((val) {
                val?.nickname = u.nickname;
                val?.faceURL = u.faceURL;

                val?.remark = u.remark;
                val?.ex = u.ex;
                val?.globalRecvMsgOpt = u.globalRecvMsgOpt;
              });
            },
            onUserStatusChanged: userStausChanged))
        ..messageManager.setAdvancedMsgListener(OnAdvancedMsgListener(
          onRecvC2CReadReceipt: recvC2CMessageReadReceipt,
          onRecvNewMessage: recvNewMessage,
          onNewRecvMessageRevoked: recvMessageRevoked,
          onRecvOfflineNewMessage: recvOfflineMessage,
          onRecvOnlineOnlyMessage: (msg) {
            if (msg.isCustomType) {
              final payload = IMUtils.decodeCustomMessageMap(msg);
              final customType = IMUtils.customMessageType(msg);
              if (payload != null &&
                  customType != null &&
                  (customType == CustomMessageType.callingInvite ||
                      customType == CustomMessageType.callingAccept ||
                      customType == CustomMessageType.callingReject ||
                      customType == CustomMessageType.callingCancel ||
                      customType == CustomMessageType.callingHungup)) {
                final rawData = payload['data'];
                Map<String, dynamic> invitationData;
                if (rawData is Map<String, dynamic>) {
                  invitationData = Map<String, dynamic>.from(rawData);
                } else if (rawData is Map) {
                  final temp = <String, dynamic>{};
                  rawData.forEach((key, value) {
                    final stringKey = key is String ? key : key?.toString();
                    if (stringKey != null && stringKey.isNotEmpty) {
                      temp[stringKey] = value;
                    }
                  });
                  invitationData = temp;
                } else {
                  invitationData = IMUtils.customMessageData(msg);
                }
                final signaling = SignalingInfo(invitation: InvitationInfo.fromJson(invitationData));
                signaling.userID = signaling.invitation?.inviterUserID;

                switch (customType) {
                  case CustomMessageType.callingInvite:
                    receiveNewInvitation(signaling);
                    break;
                  case CustomMessageType.callingAccept:
                    inviteeAccepted(signaling);
                    break;
                  case CustomMessageType.callingReject:
                    inviteeRejected(signaling);
                    break;
                  case CustomMessageType.callingCancel:
                    invitationCancelled(signaling);
                    break;
                  case CustomMessageType.callingHungup:
                    beHangup(signaling);
                    break;
                }
              }
            }
          },
        ))
        ..messageManager.setMsgSendProgressListener(OnMsgSendProgressListener(
          onProgress: progressCallback,
        ))
        ..messageManager.setCustomBusinessListener(OnCustomBusinessListener(
          onRecvCustomBusinessMessage: recvCustomBusinessMessage,
        ))
        ..friendshipManager.setFriendshipListener(OnFriendshipListener(
          onBlackAdded: blacklistAdded,
          onBlackDeleted: blacklistDeleted,
          onFriendApplicationAccepted: friendApplicationAccepted,
          onFriendApplicationAdded: friendApplicationAdded,
          onFriendApplicationDeleted: friendApplicationDeleted,
          onFriendApplicationRejected: friendApplicationRejected,
          onFriendInfoChanged: friendInfoChanged,
          onFriendAdded: friendAdded,
          onFriendDeleted: friendDeleted,
        ))
        ..conversationManager.setConversationListener(OnConversationListener(
            onConversationChanged: conversationChanged,
            onNewConversation: newConversation,
            onTotalUnreadMessageCountChanged: totalUnreadMsgCountChanged,
            onInputStatusChanged: inputStateChanged,
            onSyncServerFailed: (reInstall) {
              imSdkStatus(IMSdkStatus.syncFailed, reInstall: reInstall ?? false);
            },
            onSyncServerFinish: (reInstall) {
              imSdkStatus(IMSdkStatus.syncEnded, reInstall: reInstall ?? false);
            },
            onSyncServerStart: (reInstall) {
              imSdkStatus(IMSdkStatus.syncStart, reInstall: reInstall ?? false);
            },
            onSyncServerProgress: (progress) {
              imSdkStatus(IMSdkStatus.syncProgress, progress: progress);
            }))
        ..groupManager.setGroupListener(OnGroupListener(
          onGroupApplicationAccepted: groupApplicationAccepted,
          onGroupApplicationAdded: groupApplicationAdded,
          onGroupApplicationDeleted: groupApplicationDeleted,
          onGroupApplicationRejected: groupApplicationRejected,
          onGroupInfoChanged: groupInfoChanged,
          onGroupMemberAdded: groupMemberAdded,
          onGroupMemberDeleted: groupMemberDeleted,
          onGroupMemberInfoChanged: groupMemberInfoChanged,
          onJoinedGroupAdded: joinedGroupAdded,
          onJoinedGroupDeleted: joinedGroupDeleted,
        ));

      if (initialized) {
        Logger().sdkIsInited = true;
        initializedSubject.sink.add(true);
        if (!_initCompleter.isCompleted) {
          _initCompleter.complete();
        }
      } else {
        Logger.print('OpenIM SDK init returned false', onlyConsole: true);
        initializedSubject.sink.add(false);
        if (!_initCompleter.isCompleted) {
          _initCompleter.completeError(StateError('initSDK returned false'));
        }
      }
    } catch (e, s) {
      Logger.print('OpenIM SDK init error: $e\n$s', onlyConsole: true);
      initializedSubject.sink.add(false);
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    } finally {
      _initInProgress = false;
    }
  }

  Future login(String userID, String token) async {
    await ensureInitialized();
    try {
      UserInfo user = await _runWithSdkReady(() => OpenIM.iMManager.login(
            userID: userID,
            token: token,
            defaultValue: () async => UserInfo(userID: userID),
          ));
      userInfo = UserFullInfo.fromJson(user.toJson()).obs;
      _queryMyFullInfo();
      _queryAtAllTag();
    } catch (e, s) {
      Logger.print('e: $e  s:$s');
      await _handleLoginRepeatError(e);

      return Future.error(e, s);
    }
  }

  Future logout() async {
    await OpenIM.iMManager.logout();
    await BackgroundConnectionService.stop();
  }

  Future<T> _runWithSdkReady<T>(Future<T> Function() task) async {
    PlatformException? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await task();
      } on PlatformException catch (e) {
        if (!IMUtils.isSdkNotInitError(e) || attempt == 2) {
          rethrow;
        }
        last = e;
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    if (last != null) {
      throw last;
    }
    throw PlatformException(code: 'sdk_not_ready');
  }

  void _queryAtAllTag() async {
    atAllTag = OpenIM.iMManager.conversationManager.atAllTag;
  }

  void _queryMyFullInfo() async {
    final data = await Apis.queryMyFullInfo();
    if (data is UserFullInfo) {
      userInfo.update((val) {
        val?.allowAddFriend = data.allowAddFriend;
        val?.allowBeep = data.allowBeep;
        val?.allowVibration = data.allowVibration;
        val?.nickname = data.nickname;
        val?.faceURL = data.faceURL;
        val?.phoneNumber = data.phoneNumber;
        val?.email = data.email;
        val?.birth = data.birth;
        val?.gender = data.gender;
      });
    }
  }

  _handleLoginRepeatError(e) async {
    if (e is PlatformException && (e.code == "13002" || e.code == '1507')) {
      await logout();
      await DataSp.removeLoginCertificate();
    }
  }
}
